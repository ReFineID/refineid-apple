// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The document security store: the certificates, OCSP responses and
/// CRLs a validator needs to judge a signature long after its
/// certificates expire (ISO 32000-2 §12.8.4.3, ETSI EN 319 142-1).
///
/// Written as its own incremental revision after the signature is in
/// place, because it is evidence *about* that signature. Each blob is
/// a raw stream object with no filter: a validator reading these
/// wants the bytes the responder signed, not a re-encoding.
public enum PdfValidationStore {
  /// Inputs already resolved for one incremental DSS revision.
  private struct RevisionContext {
    /// The document receiving the revision.
    let document: Data

    /// The document's newest cross-reference index.
    let index: PdfDocumentIndex

    /// The catalog object's number.
    let rootNumber: Int

    /// The next unused object number before this revision.
    let size: Int

    /// The catalog body.
    let catalog: String

    /// New validation material.
    let material: Material

    /// Material retained from the earlier DSS.
    let previous: PreviousStore
  }

  /// References assigned to newly appended evidence streams.
  private struct AddedMaterial {
    /// New certificate references.
    let certificates: [StoreReference]

    /// New OCSP response references.
    let ocspResponses: [StoreReference]

    /// New CRL references.
    let revocationLists: [StoreReference]
  }

  /// The material collected for one signature.
  public struct Material: Equatable, Sendable {
    /// Certificates of the chain, the signer's own excluded - it
    /// travels in the CMS.
    public let certificates: [Data]

    /// OCSP responses, as the responders returned them.
    public let ocspResponses: [Data]

    /// CRLs, as the issuers published them.
    public let revocationLists: [Data]

    /// Whether there is nothing to write.
    public var isEmpty: Bool {
      certificates.isEmpty && ocspResponses.isEmpty && revocationLists.isEmpty
    }

    /// Groups one signature's evidence.
    public init(
      certificates: [Data],
      ocspResponses: [Data],
      revocationLists: [Data]
    ) {
      self.certificates = certificates
      self.ocspResponses = ocspResponses
      self.revocationLists = revocationLists
    }
  }

  /// Appends the store as one incremental revision.
  ///
  /// Empty material answers the input unchanged: a revision that adds
  /// nothing is a revision that should not exist.
  public static func appended(
    to document: Data,
    material: Material
  ) throws -> Data {
    guard !material.isEmpty else { return document }
    let index = try PdfDocumentIndex.parse(document)
    guard
      let rootNumber = PdfDocumentIndex.reference(named: "/Root", in: index.trailer),
      let size = PdfDocumentIndex.integer(named: "/Size", in: index.trailer),
      let catalog = index.body(of: rootNumber, in: document)
    else {
      throw PdfSigningError.structureUnreadable
    }
    let previous = try Self.previousStore(
      in: catalog, index: index, document: document
    )
    return try Self.appendedRevision(
      RevisionContext(
        document: document,
        index: index,
        rootNumber: rootNumber,
        size: size,
        catalog: catalog,
        material: material,
        previous: previous
      )
    )
  }

  /// Writes the objects and cross-reference section of the new revision.
  private static func appendedRevision(_ context: RevisionContext) throws -> Data {
    var out = context.document
    if out.last != UInt8(ascii: "\n") {
      out.append(UInt8(ascii: "\n"))
    }
    var offsets: [Int: Int] = [:]
    var next = max(context.size, 1)
    let added = Self.appendMaterialBlobs(
      context.material, into: &out, offsets: &offsets, next: &next
    )

    let storeBody = Self.storeDictionary(
      certificates: context.previous.certificates + added.certificates,
      ocspResponses: context.previous.ocspResponses + added.ocspResponses,
      revocationLists: context.previous.revocationLists + added.revocationLists,
      previous: context.previous
    )
    let storeNumber = next
    next += 1
    offsets[storeNumber] = out.count
    guard let storeBytes = storeBody.data(using: .isoLatin1) else {
      throw PdfSigningError.structureUnreadable
    }
    out.append(Data("\(storeNumber) 0 obj\n".utf8))
    out.append(storeBytes)
    out.append(Data("\nendobj\n".utf8))

    offsets[context.rootNumber] = out.count
    let updatedCatalog = try Self.catalogReferencing(
      storeNumber, in: context.catalog
    )
    guard let catalogBytes = updatedCatalog.data(using: .isoLatin1) else {
      throw PdfSigningError.structureUnreadable
    }
    out.append(Data("\(context.rootNumber) 0 obj\n".utf8))
    out.append(catalogBytes)
    out.append(Data("\nendobj\n".utf8))

    let xrefOffset = out.count
    out.append(
      try PdfIncrementalSigner.crossReferenceSection(
        offsets: offsets,
        size: next,
        rootNumber: context.rootNumber,
        xrefOffset: xrefOffset,
        index: context.index
      )
    )
    return out
  }

  /// Appends the three kinds of new evidence stream.
  private static func appendMaterialBlobs(
    _ material: Material,
    into out: inout Data,
    offsets: inout [Int: Int],
    next: inout Int
  ) -> AddedMaterial {
    let certificates = Self.appendBlobs(
      Self.orderedUnique(material.certificates),
      into: &out,
      offsets: &offsets,
      next: &next
    )
    let ocspResponses = Self.appendBlobs(
      Self.orderedUnique(material.ocspResponses),
      into: &out,
      offsets: &offsets,
      next: &next
    )
    let revocationLists = Self.appendBlobs(
      Self.orderedUnique(material.revocationLists),
      into: &out,
      offsets: &offsets,
      next: &next
    )
    return AddedMaterial(
      certificates: certificates,
      ocspResponses: ocspResponses,
      revocationLists: revocationLists
    )
  }

  /// Appends one stream object per blob, answering their numbers.
  private static func appendBlobs(
    _ blobs: [Data],
    into out: inout Data,
    offsets: inout [Int: Int],
    next: inout Int
  ) -> [StoreReference] {
    var references: [StoreReference] = []
    for blob in blobs {
      let number = next
      next += 1
      offsets[number] = out.count
      out.append(Data("\(number) 0 obj\n<< /Length \(blob.count) >>\nstream\n".utf8))
      out.append(blob)
      out.append(Data("\nendstream\nendobj\n".utf8))
      references.append(StoreReference(number: number, generation: 0))
    }
    return references
  }

  /// The store dictionary; empty categories are omitted entirely.
  private static func storeDictionary(
    certificates: [StoreReference],
    ocspResponses: [StoreReference],
    revocationLists: [StoreReference],
    previous: PreviousStore
  ) -> String {
    var entries = ["/Type /DSS"]
    for (key, references) in [
      ("/Certs", certificates),
      ("/OCSPs", ocspResponses),
      ("/CRLs", revocationLists),
    ] where !references.isEmpty {
      let values = Self.orderedUnique(references).map(\.rendered)
      entries.append("\(key) [\(values.joined(separator: " "))]")
    }
    if let vri = previous.vri {
      entries.append("/VRI \(vri)")
    }
    entries.append(contentsOf: previous.otherEntries)
    return "<< \(entries.joined(separator: " ")) >>"
  }
}
