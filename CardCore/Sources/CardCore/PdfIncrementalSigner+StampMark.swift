// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The signature's visible mark, as the signature field's own
/// appearance (ISO 32000-1 §12.5.5 appearance streams, §12.7.5.5
/// signature fields).
///
/// The mark is the widget's appearance stream, not content drawn on
/// the page. That distinction is the whole of it. A validator sorts
/// what changed after a signature into what a signature field is
/// allowed to add and what modifies the document: an appearance
/// belongs to the field, while a content stream added to a page is a
/// modification, and reports as one against every signature already
/// there. Built this way a second signer's mark costs the first
/// signature nothing.
extension PdfIncrementalSigner {
  /// The object numbers this revision writes.
  ///
  /// Allocated in one run from the trailer's size, so a reader meets
  /// them in the order they were written.
  internal struct PageNumbers {
    /// The signature's widget.
    internal let field: Int

    /// The widget's appearance stream.
    internal let appearance: Int

    /// Numbers, counting from the first free one: the signature takes
    /// it, then the widget and the appearance.
    internal init(firstFree: Int) {
      var next = firstFree
      next += 1
      self.field = next
      next += 1
      self.appearance = next
    }
  }

  /// Where a mark goes, and what draws it.
  internal struct StampPlacement {
    /// The widget's rectangle on the page.
    internal let rectangle: String

    /// The page the widget belongs to.
    internal let page: Int
  }

  /// Where this mark lands on the document's last page.
  ///
  /// A document can be signed by more than one person and each mark
  /// is placed by the same rule, so a later one would land on an
  /// earlier one. Ours are marked, counted, and stepped aside from:
  /// along the foot from the right, then up a row when the next would
  /// not clear the left edge.
  internal static func stampPlacement(
    source: RevisionSource,
    stamp: StampMark
  ) throws -> StampPlacement {
    let index = source.index
    let document = source.document
    guard
      let catalog = index.body(of: source.rootNumber, in: document),
      let pageNumber = try? Self.lastPage(
        index: index, document: document, catalog: catalog
      ),
      let page = index.body(of: pageNumber, in: document)
    else {
      throw PdfSigningError.structureUnreadable
    }
    let box = Self.mediaBox(of: page)
    let already = Self.stampsAlreadyOn(
      page: page, index: index, document: document
    )
    let reach = stamp.reach
    let step = reach * PdfValues.stampDiameters + PdfValues.stampGap
    let firstX = box.width - reach - PdfValues.stampMargin
    let firstY = reach + PdfValues.stampMargin
    let perRow = max(Int((firstX - reach) / step) + 1, 1)
    // A caller that looked at the page and found somewhere clear
    // says so; otherwise the corner, stepping aside from marks
    // already there.
    let centreX =
      stamp.acrossPage ?? (firstX - Double(already % perRow) * step)
    let centreY = stamp.upPage ?? (firstY + Double(already / perRow) * step)
    let corners = [
      centreX - reach, centreY - reach,
      centreX + reach, centreY + reach,
    ]
    return StampPlacement(
      rectangle: "[" + corners.map(Self.placed).joined(separator: " ") + "]",
      page: pageNumber
    )
  }

  /// Writes the appearance and the page that carries the widget.
  internal static func appendRevisionBody(
    into out: inout Data,
    offsets: inout [Int: Int],
    source: RevisionSource,
    numbers: PageNumbers,
    stamp: StampMark?
  ) throws -> Int {
    guard let stamp else {
      try Self.appendReissuedObjects(
        into: &out,
        offsets: &offsets,
        source: source,
        rootNumber: source.rootNumber,
        fieldNumber: numbers.field
      )
      return numbers.field
    }
    let placement = try Self.stampPlacement(source: source, stamp: stamp)
    offsets[numbers.appearance] = out.count
    out.append(Self.appearanceStream(numbers.appearance, stamp: stamp))

    guard
      let page = source.index.body(of: placement.page, in: source.document)
    else {
      throw PdfSigningError.structureUnreadable
    }
    let pageEntry = Self.pageReissue(
      source: source,
      page: page,
      pageNumber: placement.page,
      field: numbers.field
    )
    offsets[pageEntry.number] = out.count
    guard let body = pageEntry.body.data(using: .isoLatin1) else {
      throw PdfSigningError.structureUnreadable
    }
    out.append(Data("\(pageEntry.number) 0 obj\n".utf8))
    out.append(body)
    out.append(Data("\nendobj\n".utf8))
    try Self.appendFormReissue(
      into: &out,
      offsets: &offsets,
      source: source,
      rootNumber: source.rootNumber,
      fieldNumber: numbers.field
    )
    return numbers.appearance
  }

  /// The appearance stream drawing the mark.
  ///
  /// Its box is centred on the origin because the mark is drawn about
  /// its own centre; a reader maps that box onto the widget's
  /// rectangle, so no placement arithmetic is repeated here. Encoded
  /// as Latin-1, as a content stream is.
  private static func appearanceStream(
    _ number: Int,
    stamp: StampMark
  ) -> Data {
    let body =
      stamp.operators.data(using: .windowsCP1252, allowLossyConversion: true)
      ?? Data(stamp.operators.utf8)
    let reach = stamp.reach
    let box =
      "[\(Self.placed(-reach)) \(Self.placed(-reach))"
      + " \(Self.placed(reach)) \(Self.placed(reach))]"
    let fontResources =
      "<< /Font << /F1 << /Type /Font /Subtype /Type1 "
      + "/BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >> >> >>"
    let header =
      "\(number) 0 obj\n<< /Type /XObject /Subtype /Form /BBox \(box)"
      + " /Resources \(fontResources) /Length \(body.count) >>\nstream\n"
    var object = Data(header.utf8)
    object.append(body)
    object.append(Data("\nendstream\nendobj\n\n".utf8))
    return object
  }

  /// How many marks this page already carries.
  ///
  /// Counted from the annotations the page names, by the key each of
  /// ours is written with - a reader ignores keys it does not know.
  private static func stampsAlreadyOn(
    page: String,
    index: PdfDocumentIndex,
    document: Data
  ) -> Int {
    let listing: Substring
    if let annotsNumber = PdfDocumentIndex.reference(named: "/Annots", in: page),
      let annots = index.body(of: annotsNumber, in: document)
    {
      guard
        let open = annots.firstIndex(of: "["),
        let close = annots[open...].firstIndex(of: "]")
      else { return 0 }
      listing = annots[annots.index(after: open)..<close]
    } else if let range = page.range(of: "/Annots") {
      let rest = page[range.upperBound...].drop(while: \.isWhitespace)
      guard rest.first == "[" else { return 0 }
      listing = rest.dropFirst().prefix { character in character != "]" }
    } else {
      return 0
    }
    let numbers = listing.split(separator: "R").compactMap { part in
      Int(part.split(whereSeparator: \.isWhitespace).first ?? "")
    }
    return numbers.count { number in
      index.body(of: number, in: document)?.contains(PdfValues.stampMarker)
        == true
    }
  }

  /// One placement number, without an exponent: PDF has no notation
  /// for one, and a reader meeting it skips the operator or refuses
  /// the stream.
  private static func placed(_ value: Double) -> String {
    String(format: "%.4f", value)
  }

  /// The page's box, or A4 when it does not state one.
  private static func mediaBox(of page: String) -> (width: Double, height: Double) {
    guard
      let range = page.range(of: "/MediaBox"),
      let open = page[range.upperBound...].firstIndex(of: "["),
      let close = page[open...].firstIndex(of: "]")
    else {
      return (PdfValues.a4Width, PdfValues.a4Height)
    }
    let numbers = page[page.index(after: open)..<close]
      .split(whereSeparator: \.isWhitespace)
      .compactMap { part in Double(part) }
    guard numbers.count == PdfValues.boxCorners else {
      return (PdfValues.a4Width, PdfValues.a4Height)
    }
    let lowerLeftX = numbers[PdfValues.boxLowerLeftX]
    let lowerLeftY = numbers[PdfValues.boxLowerLeftY]
    let upperRightX = numbers[PdfValues.boxUpperRightX]
    let upperRightY = numbers[PdfValues.boxUpperRightY]
    return (upperRightX - lowerLeftX, upperRightY - lowerLeftY)
  }

  /// The last page of the document: the deepest tree's last kid.
  private static func lastPage(
    index: PdfDocumentIndex,
    document: Data,
    catalog: String
  ) throws -> Int {
    guard
      var current = PdfDocumentIndex.reference(named: "/Pages", in: catalog)
    else {
      throw PdfSigningError.structureUnreadable
    }
    for _ in 0..<PdfValues.pageTreeDepthLimit {
      guard let body = index.body(of: current, in: document) else {
        throw PdfSigningError.structureUnreadable
      }
      guard let kids = body.range(of: "/Kids") else { return current }
      let rest = body[kids.upperBound...]
      guard
        let open = rest.firstIndex(of: "["),
        let close = rest[open...].firstIndex(of: "]")
      else {
        throw PdfSigningError.structureUnreadable
      }
      let references = rest[rest.index(after: open)..<close]
        .split(separator: "R")
        .compactMap { part in
          Int(part.split(whereSeparator: \.isWhitespace).first ?? "")
        }
      guard let last = references.last else {
        throw PdfSigningError.structureUnreadable
      }
      current = last
    }
    throw PdfSigningError.structureUnreadable
  }

  /// A PDF date string, always UTC.
  internal static func pdfDate(_ instant: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    guard let utc = TimeZone(identifier: "UTC") else {
      return ""
    }
    calendar.timeZone = utc
    let parts = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: instant
    )
    return String(
      format: "D:%04d%02d%02d%02d%02d%02d+00'00'",
      parts.year ?? 0,
      parts.month ?? 0,
      parts.day ?? 0,
      parts.hour ?? 0,
      parts.minute ?? 0,
      parts.second ?? 0
    )
  }

  /// The stamp to show on this revision, omitted when a stamp is already present.
  internal static func effectiveStamp(
    _ stamp: StampMark?,
    source: RevisionSource
  ) -> StampMark? {
    guard let stamp else { return nil }
    guard
      let catalog = source.index.body(of: source.rootNumber, in: source.document),
      let pageNumber = try? Self.lastPage(
        index: source.index, document: source.document, catalog: catalog
      ),
      let page = source.index.body(of: pageNumber, in: source.document)
    else {
      return stamp
    }
    let already = Self.stampsAlreadyOn(
      page: page, index: source.index, document: source.document
    )
    return already == 0 ? stamp : nil
  }
}
