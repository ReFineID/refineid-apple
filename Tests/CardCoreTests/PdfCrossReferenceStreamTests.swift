// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Compression
import Foundation
import Testing

/// Signing documents whose structure sits behind a cross-reference
/// stream (ISO 32000-1 §7.5.8) with the catalog compressed into an
/// object stream (§7.5.7), the shape PDF 1.5 writers emit.
@Suite
internal struct PdfCrossReferenceStreamTests {
  /// The object stream's number in every fixture.
  private static let containerNumber = 4

  /// The cross-reference stream's number in every fixture.
  private static let xrefNumber = 5

  /// One past the highest fixture object number.
  private static let fixtureSize = 6

  /// Width of the offset field the fixtures write.
  private static let offsetWidth = 2

  /// The PNG Up row filter code.
  private static let upFilter: UInt8 = 2

  /// Type code of a free entry (ISO 32000-1 Table 18).
  private static let freeType: UInt8 = 0

  /// Type code of an entry at a byte offset in the file.
  private static let directType: UInt8 = 1

  /// Type code of an entry inside an object stream.
  private static let compressedType: UInt8 = 2

  /// Mask selecting the low byte of an offset.
  private static let lowByte = 0xFF

  /// Headroom for the encoder's own framing.
  private static let deflateHeadroom = 256

  /// One claim, for the tests that do not care what it says.
  private static var claim: PdfIncrementalSigner.SignatureClaim {
    PdfIncrementalSigner.SignatureClaim(
      signedAt: Date(timeIntervalSince1970: 0), reason: nil, location: nil
    )
  }

  /// The three document objects every fixture compresses.
  private static var compressedBodies: [String] {
    [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>",
    ]
  }

  /// The object stream carrying the three document objects.
  private static func objectStream() -> Data {
    var header = ""
    var contents = ""
    for (index, body) in Self.compressedBodies.enumerated() {
      header += "\(index + 1) \(contents.utf8.count) "
      contents += body + "\n"
    }
    let payload = header + contents
    var out = Data("\(Self.containerNumber) 0 obj\n".utf8)
    out.append(
      Data(
        """
        << /Type /ObjStm /N \(Self.compressedBodies.count) \
        /First \(header.utf8.count) /Length \(payload.utf8.count) >>
        """.utf8
      )
    )
    out.append(Data("\nstream\n\(payload)\nendstream\nendobj\n".utf8))
    return out
  }

  /// The entry rows of the fixture's cross-reference stream:
  /// object 0 free, the document objects compressed, the two stream
  /// objects direct.
  private static func entryRows(
    containerAt containerOffset: Int,
    xrefAt xrefOffset: Int
  ) -> Data {
    var rows = Data()
    rows.append(contentsOf: [Self.freeType, 0, 0, 0, 0])
    for position in Self.compressedBodies.indices {
      rows.append(Self.compressedType)
      rows.append(contentsOf: Self.wide(Self.containerNumber))
      rows.append(contentsOf: Self.wide(position))
    }
    for offset in [containerOffset, xrefOffset] {
      rows.append(Self.directType)
      rows.append(contentsOf: Self.wide(offset))
      rows.append(contentsOf: Self.wide(0))
    }
    return rows
  }

  /// One value as the fixture's two-byte big-endian field.
  private static func wide(_ value: Int) -> [UInt8] {
    [
      UInt8((value >> UInt8.bitWidth) & Self.lowByte),
      UInt8(value & Self.lowByte),
    ]
  }

  /// A minimal PDF closed by a cross-reference stream, optionally
  /// with its rows behind the PNG Up predictor and FlateDecode.
  private static func streamPdf(encoded: Bool = false) -> Data {
    var out = Data("%PDF-1.7\n".utf8)
    let containerOffset = out.count
    out.append(Self.objectStream())
    let xrefOffset = out.count
    var rows = Self.entryRows(
      containerAt: containerOffset, xrefAt: xrefOffset
    )
    var parameters = ""
    if encoded {
      let columns = 1 + Self.offsetWidth + Self.offsetWidth
      rows = Self.deflated(Self.predicted(rows, columns: columns))
      parameters =
        " /Filter /FlateDecode"
        + " /DecodeParms << /Predictor 12 /Columns \(columns) >>"
    }
    out.append(
      Data(
        """
        \(Self.xrefNumber) 0 obj
        << /Type /XRef /Size \(Self.fixtureSize) /Root 1 0 R \
        /W [1 \(Self.offsetWidth) \(Self.offsetWidth)]\(parameters) \
        /Length \(rows.count) >>
        stream

        """.utf8
      )
    )
    out.append(rows)
    out.append(Data("\nendstream\nendobj\nstartxref\n\(xrefOffset)\n%%EOF\n".utf8))
    return out
  }

  /// The rows rewritten as PNG Up rows, each relative to the one
  /// above it.
  private static func predicted(_ rows: Data, columns: Int) -> Data {
    let input = [UInt8](rows)
    var out = Data()
    var above = [UInt8](repeating: 0, count: columns)
    var cursor = 0
    while cursor < input.count {
      let row = Array(input[cursor..<(cursor + columns)])
      cursor += columns
      out.append(Self.upFilter)
      for column in row.indices {
        out.append(row[column] &- above[column])
      }
      above = row
    }
    return out
  }

  /// The bytes deflated the way FlateDecode expects.
  private static func deflated(_ data: Data) -> Data {
    let input = [UInt8](data)
    var output = [UInt8](
      repeating: 0, count: input.count + Self.deflateHeadroom
    )
    let written = compression_encode_buffer(
      &output, output.count, input, input.count, nil, COMPRESSION_ZLIB
    )
    return Data(output.prefix(written))
  }

  /// The document as Latin-1, the way the writer reads it.
  private static func text(_ document: Data) -> String {
    String(bytes: document, encoding: .isoLatin1) ?? ""
  }

  /// The offset the fixture's `startxref` names.
  private static func startXref(of document: Data) -> Int {
    let text = Self.text(document)
    guard let found = text.range(of: "startxref\n", options: .backwards)
    else {
      return -1
    }
    let digits = text[found.upperBound...].prefix(while: \.isNumber)
    return Int(digits) ?? -1
  }

  @Test
  internal func signsBehindCrossReferenceStream() throws {
    let document = Self.streamPdf()
    let placeholder = try PdfIncrementalSigner.prepare(
      document, revision: .signature(Self.claim)
    )
    let update = Self.text(placeholder.document.dropFirst(document.count))
    #expect(placeholder.document.starts(with: document))
    #expect(update.contains("/SubFilter /ETSI.CAdES.detached"))
    #expect(update.contains("/Prev \(Self.startXref(of: document))"))
  }

  @Test
  internal func closesTheRevisionWithAStream() throws {
    let document = Self.streamPdf()
    let placeholder = try PdfIncrementalSigner.prepare(
      document, revision: .signature(Self.claim)
    )
    let update = Self.text(placeholder.document.dropFirst(document.count))
    #expect(update.contains("/Type /XRef"))
    #expect(update.contains("trailer") == false)
  }

  @Test
  internal func readsTheCatalogOutOfTheObjectStream() throws {
    let document = Self.streamPdf()
    let placeholder = try PdfIncrementalSigner.prepare(
      document, revision: .signature(Self.claim)
    )
    let update = Self.text(placeholder.document.dropFirst(document.count))
    #expect(update.contains("/Type /Catalog"))
    #expect(update.contains("/AcroForm"))
  }

  @Test
  internal func extendsItsOwnStreamRevision() throws {
    let first = try PdfIncrementalSigner.prepare(
      Self.streamPdf(), revision: .signature(Self.claim)
    )
    let second = try PdfIncrementalSigner.prepare(
      first.document, revision: .documentTimestamp
    )
    #expect(second.document.starts(with: first.document))
  }

  @Test
  internal func decodesFlateBehindTheUpPredictor() throws {
    let document = Self.streamPdf(encoded: true)
    let placeholder = try PdfIncrementalSigner.prepare(
      document, revision: .signature(Self.claim)
    )
    #expect(Self.text(placeholder.document).contains("/AcroForm"))
  }

  @Test
  internal func appendsValidationStoreBehindStream() throws {
    let document = Self.streamPdf()
    let material = PdfValidationStore.Material(
      certificates: [Data("certificate".utf8)],
      ocspResponses: [],
      revocationLists: []
    )
    let out = try PdfValidationStore.appended(to: document, material: material)
    let update = Self.text(out.dropFirst(document.count))
    #expect(update.contains("/Type /DSS"))
    #expect(update.contains("trailer") == false)
    #expect(update.contains("/Type /XRef"))
  }
}
