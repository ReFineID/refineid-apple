// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Reading the validation store already present in a PDF.
extension PdfValidationStore {
  /// One indirect object reference retained from an earlier store.
  internal struct StoreReference: Hashable {
    /// The indirect object's number.
    internal let number: Int

    /// The indirect object's generation.
    internal let generation: Int

    /// The PDF spelling of the reference.
    internal var rendered: String {
      "\(number) \(generation) R"
    }
  }

  /// Values carried from the newest store into its replacement.
  internal struct PreviousStore {
    /// A document that has no earlier store.
    internal static let empty = Self(
      certificates: [],
      ocspResponses: [],
      revocationLists: [],
      vri: nil,
      otherEntries: []
    )

    /// Certificate stream references.
    internal let certificates: [StoreReference]

    /// OCSP response stream references.
    internal let ocspResponses: [StoreReference]

    /// CRL stream references.
    internal let revocationLists: [StoreReference]

    /// The VRI value, copied without re-encoding.
    internal let vri: String?

    /// Extension entries this writer does not interpret.
    internal let otherEntries: [String]
  }

  /// Reads the newest store, failing instead of discarding an unreadable one.
  internal static func previousStore(
    in catalog: String,
    index: PdfDocumentIndex,
    document: Data
  ) throws -> PreviousStore {
    let catalogSyntax = try DictionarySyntax(catalog)
    guard let storeEntry = catalogSyntax.entry(named: "DSS") else {
      return .empty
    }
    let storeText = try Self.dictionaryText(
      for: catalogSyntax.value(of: storeEntry),
      index: index,
      document: document
    )
    let store = try DictionarySyntax(storeText)
    var certificates: [StoreReference] = []
    var ocspResponses: [StoreReference] = []
    var revocationLists: [StoreReference] = []
    var vri: String?
    var otherEntries: [String] = []

    for entry in store.entries {
      let value = store.value(of: entry)
      switch entry.name {
      case "Certs":
        certificates = try Self.references(
          in: value, index: index, document: document
        )

      case "CRLs":
        revocationLists = try Self.references(
          in: value, index: index, document: document
        )

      case "OCSPs":
        ocspResponses = try Self.references(
          in: value, index: index, document: document
        )

      case "Type":
        continue

      case "VRI":
        _ = try Self.dictionaryText(
          for: value, index: index, document: document
        )
        vri = value

      default:
        otherEntries.append("\(entry.rawName) \(value)")
      }
    }
    return PreviousStore(
      certificates: certificates,
      ocspResponses: ocspResponses,
      revocationLists: revocationLists,
      vri: vri,
      otherEntries: otherEntries
    )
  }

  /// The catalog with its top-level DSS value added or replaced.
  internal static func catalogReferencing(
    _ storeNumber: Int,
    in catalog: String
  ) throws -> String {
    try DictionarySyntax(catalog).replacing(
      name: "DSS", value: "\(storeNumber) 0 R"
    )
  }

  /// Removes duplicates without changing the first-seen order.
  internal static func orderedUnique<Element: Hashable>(
    _ values: [Element]
  ) -> [Element] {
    var seen: Set<Element> = []
    return values.filter { value in seen.insert(value).inserted }
  }

  /// Resolves a direct dictionary or one indirect dictionary object.
  private static func dictionaryText(
    for value: String,
    index: PdfDocumentIndex,
    document: Data
  ) throws -> String {
    if (try? DictionarySyntax(value)) != nil {
      return value
    }
    guard
      let reference = try ValueParser.reference(in: value),
      let body = index.body(of: reference.number, in: document),
      (try? DictionarySyntax(body)) != nil
    else {
      throw PdfSigningError.structureUnreadable
    }
    return body
  }

  /// Resolves one DSS category's direct or indirect reference array.
  private static func references(
    in value: String,
    index: PdfDocumentIndex,
    document: Data
  ) throws -> [StoreReference] {
    if let direct = try? ValueParser.referenceArray(in: value) {
      return direct
    }
    guard
      let reference = try ValueParser.reference(in: value),
      let body = index.body(of: reference.number, in: document)
    else {
      throw PdfSigningError.structureUnreadable
    }
    return try ValueParser.referenceArray(in: body)
  }
}
