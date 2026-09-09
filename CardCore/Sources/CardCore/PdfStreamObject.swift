// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One indirect stream object: its dictionary and its decoded payload
/// (ISO 32000-1 §7.3.8 streams, §7.4.4 FlateDecode and predictors).
///
/// Serves the two stream shapes the cross-reference chain can name:
/// cross-reference streams and the object streams they index.
internal struct PdfStreamObject {
  /// The predictor value meaning none was applied.
  private static let noPredictor = 1

  /// The first of the PNG row predictors (ISO 32000-1 §7.4.4.4);
  /// values below it other than none are the TIFF predictor, which
  /// this reader does not decode.
  private static let pngPredictorFloor = 10

  /// PNG row filter: the row as written.
  private static let pngFilterNone = 0

  /// PNG row filter: each byte relative to its left neighbour.
  private static let pngFilterSub = 1

  /// PNG row filter: each byte relative to the byte above.
  private static let pngFilterUp = 2

  /// PNG row filter: each byte relative to the mean of left and above.
  private static let pngFilterAverage = 3

  /// PNG row filter: each byte relative to the Paeth prediction.
  private static let pngFilterPaeth = 4

  /// Divisor of the average filter's prediction.
  private static let averageDivisor = 2

  /// The samples-per-byte shape this reader decodes: one colour of
  /// eight bits, which is what cross-reference streams use.
  private static let supportedColors = 1

  /// Bits per component in the supported shape.
  private static let supportedBitsPerComponent = 8

  /// The stream dictionary, as written.
  internal let dictionary: String

  /// The payload with its filter and predictor undone.
  internal let payload: Data

  /// Parses `N G obj << ... >> stream ... endstream` at `offset`.
  internal static func parse(
    in bytes: PdfBytes,
    at offset: Int
  ) throws -> Self {
    let start = bytes.skippingWhitespace(from: offset)
    guard
      let headerEnd = Self.objectHeaderEnd(in: bytes, at: start),
      let content = bytes.balancedDictionary(from: headerEnd)
    else {
      throw PdfSigningError.structureUnreadable
    }
    let raw = try Self.rawPayload(in: bytes, after: content)
    let decoded = try Self.decoded(raw, dictionary: content.text)
    return Self(dictionary: content.text, payload: decoded)
  }

  /// The position just past the `obj` keyword, or nil when the bytes
  /// at `start` are not an object header.
  private static func objectHeaderEnd(
    in bytes: PdfBytes,
    at start: Int
  ) -> Int? {
    guard let number = bytes.decimalToken(at: start) else { return nil }
    let generationAt = bytes.skippingWhitespace(from: number.end)
    guard let generation = bytes.decimalToken(at: generationAt) else {
      return nil
    }
    let keywordAt = bytes.skippingWhitespace(from: generation.end)
    guard bytes.hasKeyword(PdfValues.objectKeyword, at: keywordAt) else {
      return nil
    }
    return keywordAt + PdfValues.objectKeyword.utf8.count
  }

  /// The raw payload bytes between `stream` and `endstream`.
  ///
  /// A direct /Length names the span exactly; without one the payload
  /// runs to the `endstream` keyword, less the line ending the format
  /// puts before it.
  private static func rawPayload(
    in bytes: PdfBytes,
    after dictionary: (text: String, end: Int)
  ) throws -> Data {
    guard
      let keyword = bytes.firstRange(
        of: PdfValues.streamKeyword, from: dictionary.end
      )
    else {
      throw PdfSigningError.structureUnreadable
    }
    // The keyword is followed by CRLF or LF (ISO 32000-1 §7.3.8.1).
    var dataStart = keyword.upperBound
    if bytes.hasKeyword("\r", at: dataStart) { dataStart += 1 }
    if bytes.hasKeyword("\n", at: dataStart) { dataStart += 1 }
    if let length = Self.directLength(in: dictionary.text),
      dataStart + length <= bytes.count
    {
      return bytes.data(in: dataStart..<(dataStart + length))
    }
    guard
      let end = bytes.firstRange(
        of: PdfValues.endStreamKeyword, from: dataStart
      )
    else {
      throw PdfSigningError.structureUnreadable
    }
    var dataEnd = end.lowerBound
    if dataEnd > dataStart, bytes.hasKeyword("\n", at: dataEnd - 1) {
      dataEnd -= 1
    }
    if dataEnd > dataStart, bytes.hasKeyword("\r", at: dataEnd - 1) {
      dataEnd -= 1
    }
    return bytes.data(in: dataStart..<dataEnd)
  }

  /// The direct /Length value, or nil when absent or indirect.
  private static func directLength(in dictionary: String) -> Int? {
    guard let range = dictionary.range(of: "/Length") else { return nil }
    let rest = dictionary[range.upperBound...].drop(while: \.isWhitespace)
    let digits = rest.prefix(while: \.isNumber)
    guard let value = Int(digits) else { return nil }
    // `/Length N G R` is a reference, not a length of N.
    let after = rest.dropFirst(digits.count).drop(while: \.isWhitespace)
    let generation = after.prefix(while: \.isNumber)
    if !generation.isEmpty {
      let tail = after.dropFirst(generation.count)
        .drop(while: \.isWhitespace)
      if tail.first == "R" { return nil }
    }
    return value
  }

  /// The payload with its filter chain undone.
  private static func decoded(
    _ raw: Data,
    dictionary: String
  ) throws -> Data {
    let names = Self.filterNames(in: dictionary)
    let inflated: Data
    if names.isEmpty {
      inflated = raw
    } else if names == [PdfValues.flateFilterName] {
      guard
        let out = FlateDecoder.decoded(
          raw, limit: PdfValues.inflatedStreamLimit
        )
      else {
        throw PdfSigningError.structureUnreadable
      }
      inflated = out
    } else {
      throw PdfSigningError.crossReferenceStreamUnsupported
    }
    return try Self.unpredicted(inflated, dictionary: dictionary)
  }

  /// The names the /Filter entry carries, in order.
  private static func filterNames(in dictionary: String) -> [String] {
    guard
      let range = dictionary.range(of: PdfValues.filterKey)
    else {
      return []
    }
    let rest = dictionary[range.upperBound...].drop(while: \.isWhitespace)
    let value: Substring
    if rest.first == "[" {
      guard let close = rest.firstIndex(of: "]") else { return ["["] }
      value = rest[rest.startIndex..<close]
    } else {
      value = rest.prefix { character in !character.isWhitespace }
    }
    return value.split(separator: "/")
      .map { piece in
        piece.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      .filter { name in !name.isEmpty && !name.contains("[") }
  }

  /// Undoes the row predictor /DecodeParms names
  /// (ISO 32000-1 §7.4.4.4).
  private static func unpredicted(
    _ data: Data,
    dictionary: String
  ) throws -> Data {
    guard
      let predictor = PdfDocumentIndex.integer(
        named: "/Predictor", in: dictionary
      ),
      predictor != Self.noPredictor
    else {
      return data
    }
    guard predictor >= Self.pngPredictorFloor else {
      throw PdfSigningError.crossReferenceStreamUnsupported
    }
    if let colors = PdfDocumentIndex.integer(named: "/Colors", in: dictionary),
      colors != Self.supportedColors
    {
      throw PdfSigningError.crossReferenceStreamUnsupported
    }
    if let bits = PdfDocumentIndex.integer(
      named: "/BitsPerComponent", in: dictionary
    ),
      bits != Self.supportedBitsPerComponent
    {
      throw PdfSigningError.crossReferenceStreamUnsupported
    }
    let columns =
      PdfDocumentIndex.integer(named: "/Columns", in: dictionary) ?? 1
    return try Self.pngUnfiltered(data, columns: columns)
  }

  /// Undoes the per-row PNG filters over one-byte samples.
  private static func pngUnfiltered(
    _ data: Data,
    columns: Int
  ) throws -> Data {
    let rowStride = columns + 1
    guard columns > 0, data.count.isMultiple(of: rowStride) else {
      throw PdfSigningError.structureUnreadable
    }
    let input = [UInt8](data)
    var output = Data(capacity: input.count - input.count / rowStride)
    var above = [UInt8](repeating: 0, count: columns)
    var cursor = 0
    while cursor < input.count {
      let filter = Int(input[cursor])
      let row = Array(input[(cursor + 1)..<(cursor + rowStride)])
      cursor += rowStride
      let decoded = try Self.unfilteredRow(row, filter: filter, above: above)
      output.append(contentsOf: decoded)
      above = decoded
    }
    return output
  }

  /// One row with its filter undone.
  private static func unfilteredRow(
    _ row: [UInt8],
    filter: Int,
    above: [UInt8]
  ) throws -> [UInt8] {
    var decoded = [UInt8](repeating: 0, count: row.count)
    for column in row.indices {
      let left = column > 0 ? decoded[column - 1] : 0
      let upper = above[column]
      let upperLeft = column > 0 ? above[column - 1] : 0
      let prediction: UInt8
      switch filter {
      case Self.pngFilterNone:
        prediction = 0

      case Self.pngFilterSub:
        prediction = left

      case Self.pngFilterUp:
        prediction = upper

      case Self.pngFilterAverage:
        prediction = UInt8(
          (Int(left) + Int(upper)) / Self.averageDivisor
        )

      case Self.pngFilterPaeth:
        prediction = Self.paeth(
          left: left, above: upper, upperLeft: upperLeft
        )

      default:
        throw PdfSigningError.structureUnreadable
      }
      decoded[column] = row[column] &+ prediction
    }
    return decoded
  }

  /// The Paeth prediction: whichever neighbour is closest to the
  /// initial estimate `left + above - upperLeft`.
  private static func paeth(
    left: UInt8,
    above: UInt8,
    upperLeft: UInt8
  ) -> UInt8 {
    let estimate = Int(left) + Int(above) - Int(upperLeft)
    let distanceLeft = abs(estimate - Int(left))
    let distanceAbove = abs(estimate - Int(above))
    let distanceUpperLeft = abs(estimate - Int(upperLeft))
    if distanceLeft <= distanceAbove, distanceLeft <= distanceUpperLeft {
      return left
    }
    if distanceAbove <= distanceUpperLeft {
      return above
    }
    return upperLeft
  }
}
