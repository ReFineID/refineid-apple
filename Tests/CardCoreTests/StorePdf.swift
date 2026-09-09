// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// Small classic-cross-reference PDF fixtures and readers for DSS tests.
internal enum StorePdf {
  /// The catalog object in every fixture.
  private static let catalogObject = 1

  /// The page-tree object in every fixture.
  private static let pagesObject = 2

  /// The first page object in every fixture.
  private static let pageObject = 3

  /// Tokens occupied by one indirect reference.
  private static let referenceTokenCount = 3

  /// Offset of the generation token in one reference.
  private static let generationTokenOffset = 1

  /// Offset of the `R` token in one reference.
  private static let markerTokenOffset = 2

  /// Empty validation material.
  internal static let empty = PdfValidationStore.Material(
    certificates: [], ocspResponses: [], revocationLists: []
  )

  /// A material fixture with one value in each category.
  internal static func material(
    certificate: String,
    ocsp: String,
    crl: String
  ) -> PdfValidationStore.Material {
    PdfValidationStore.Material(
      certificates: [Data(certificate.utf8)],
      ocspResponses: [Data(ocsp.utf8)],
      revocationLists: [Data(crl.utf8)]
    )
  }

  /// A catalog without a DSS or extra entries.
  internal static func catalog() -> String {
    Self.catalog(dss: nil, additions: "")
  }

  /// A catalog with one DSS value.
  internal static func catalog(dss: String) -> String {
    Self.catalog(dss: dss, additions: "")
  }

  /// A catalog with extra entries and no DSS.
  internal static func catalog(additions: String) -> String {
    Self.catalog(dss: nil, additions: additions)
  }

  /// A catalog with optional DSS and extra values.
  private static func catalog(dss: String?, additions: String) -> String {
    var entries = "/Type /Catalog /Pages 2 0 R"
    if let dss { entries += " /DSS \(dss)" }
    if !additions.isEmpty { entries += " \(additions)" }
    return "<< \(entries) >>"
  }

  /// A small PDF with only its three required objects.
  internal static func document(catalog: String) -> Data {
    Self.document(catalog: catalog, extraObjects: [:])
  }

  /// A small PDF with the supplied indirect objects.
  internal static func document(
    catalog: String,
    extraObjects: [Int: String]
  ) -> Data {
    var objects: [Int: String] = [
      Self.catalogObject: catalog,
      Self.pagesObject:
        "<< /Type /Pages /Kids [\(Self.pageObject) 0 R] /Count 1 >>",
      Self.pageObject:
        "<< /Type /Page /Parent \(Self.pagesObject) 0 R"
        + " /MediaBox [0 0 612 792] >>",
    ]
    for (number, body) in extraObjects { objects[number] = body }
    var text = "%PDF-1.7\n"
    var offsets: [Int: Int] = [:]
    for number in objects.keys.sorted() {
      guard let body = objects[number] else { continue }
      offsets[number] = text.utf8.count
      text += "\(number) 0 obj\n\(body)\nendobj\n"
    }
    let size = (objects.keys.max() ?? 0) + 1
    let xrefOffset = text.utf8.count
    text += "xref\n0 \(size)\n0000000000 65535 f \n"
    for number in 1..<size {
      if let offset = offsets[number] {
        text += String(format: "%010d 00000 n \n", offset)
      } else {
        text += "0000000000 65535 f \n"
      }
    }
    text += "trailer\n<< /Size \(size) /Root 1 0 R >>\n"
    text += "startxref\n\(xrefOffset)\n%%EOF\n"
    return Data(text.utf8)
  }

  /// A stream object body for pre-existing evidence.
  internal static func stream(_ value: String) -> String {
    "<< /Length \(value.utf8.count) >>\nstream\n\(value)\nendstream"
  }

  /// The newest catalog's DSS object and body.
  internal static func latestStore(
    in document: Data
  ) -> (number: Int, body: String)? {
    guard
      let catalog = Self.latestObject(Self.catalogObject, in: document),
      let number = Self.reference(named: "/DSS", in: catalog),
      let body = Self.latestObject(number, in: document)
    else { return nil }
    return (number, body)
  }

  /// The newest body of one indirect object.
  internal static func latestObject(_ number: Int, in document: Data) -> String? {
    let text = Self.text(document)
    guard
      let start = text.range(of: "\(number) 0 obj\n", options: .backwards),
      let end = text.range(of: "\nendobj", range: start.upperBound..<text.endIndex)
    else { return nil }
    return String(text[start.upperBound..<end.lowerBound])
  }

  /// The object number held by a named indirect-reference entry.
  internal static func reference(named key: String, in dictionary: String) -> Int? {
    guard let keyRange = dictionary.range(of: key, options: .backwards) else {
      return nil
    }
    let rest = dictionary[keyRange.upperBound...].drop(while: \.isWhitespace)
    return Int(rest.prefix(while: \.isNumber))
  }

  /// The indirect references in one named direct array.
  internal static func references(named key: String, in dictionary: String) -> [String] {
    guard
      let keyRange = dictionary.range(of: key),
      let open = dictionary[keyRange.upperBound...].firstIndex(of: "["),
      let close = dictionary[open...].firstIndex(of: "]")
    else { return [] }
    let tokens = dictionary[dictionary.index(after: open)..<close]
      .split(whereSeparator: \.isWhitespace)
    var references: [String] = []
    var index = 0
    while index + Self.markerTokenOffset < tokens.count {
      references.append(
        "\(tokens[index]) \(tokens[index + Self.generationTokenOffset])"
          + " \(tokens[index + Self.markerTokenOffset])"
      )
      index += Self.referenceTokenCount
    }
    return references
  }

  /// How often an ASCII marker occurs in the document.
  internal static func occurrences(of marker: String, in document: Data) -> Int {
    Self.text(document).components(separatedBy: marker).count - 1
  }

  /// The document bytes as one-byte-preserving text.
  internal static func text(_ document: Data) -> String {
    String(data: document, encoding: .isoLatin1) ?? ""
  }
}
