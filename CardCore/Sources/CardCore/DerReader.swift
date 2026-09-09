// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A minimal DER walker.
///
/// Reads one tag-length-value at a time and answers the ranges it
/// found, so callers can keep raw encodings byte-identical - which CMS
/// requires of the issuer name and the serial number.
internal struct DerReader {
  /// One parsed element: its tag, the whole encoding, its content.
  internal struct Element {
    /// The identifier octet.
    internal let tag: UInt8

    /// The full tag-length-value range.
    internal let raw: Range<Int>

    /// The content octets range.
    internal let content: Range<Int>
  }

  /// Smallest possible element: one tag octet and one length octet.
  private static let minimumElementLength = 2

  /// The bytes being walked.
  ///
  /// Held as `Data`, not copied into an `[UInt8]`. A structure with
  /// many repeated elements - a revocation list with fifty thousand
  /// entries - constructs one reader per element, and copying the
  /// whole encoding each time made walking it quadratic in its size,
  /// on bytes whose signature has not been checked yet.
  private let bytes: Data

  /// The next unread position.
  private var offset: Int

  /// The end of the walkable region; nil means the whole input.
  private var limit: Int?

  /// Whether the reader consumed its complete selected region.
  ///
  /// A parser that accepts an expected prefix but leaves a second element
  /// behind has not validated one ASN.1 value. Protocol parsers use this
  /// after every fixed-shape structure so concatenated or smuggled values
  /// do not become silently invisible.
  internal var isAtEnd: Bool {
    offset == (limit ?? bytes.count)
  }

  /// Walks a whole encoding.
  internal init(_ encoded: Data) {
    self.bytes = Self.zeroBased(encoded)
    self.offset = 0
  }

  /// Walks one element's content.
  internal init(_ encoded: Data, within element: Element) {
    self.bytes = Self.zeroBased(encoded)
    self.offset = element.content.lowerBound
    self.limit = element.content.upperBound
  }

  /// The same bytes, indexed from zero.
  ///
  /// Every position here is an offset from the start of the encoding,
  /// but a `Data` sliced out of a larger one keeps the larger one's
  /// indices. Whole encodings - the case that repeats, and the one
  /// that made this parser quadratic - are already zero-based and are
  /// passed through untouched; a slice is rebased once.
  private static func zeroBased(_ encoded: Data) -> Data {
    encoded.startIndex == 0 ? encoded : Data(encoded)
  }

  /// Reads the next element, or nil at the end or on malformed input.
  internal mutating func next() -> Element? {
    let end = limit ?? bytes.count
    guard offset + Self.minimumElementLength <= end else { return nil }
    let tag = bytes[offset]
    var cursor = offset + 1
    var length = Int(bytes[cursor])
    cursor += 1
    if length & Int(DerValues.longFormMask) != 0 {
      let count = length & Int(DerValues.lengthCountMask)
      guard
        count >= 1, count <= DerValues.maximumLengthOctets,
        cursor + count <= end
      else { return nil }
      length = 0
      for _ in 0..<count {
        length = length << UInt8.bitWidth | Int(bytes[cursor])
        cursor += 1
      }
    }
    guard cursor + length <= end else { return nil }
    let element = Element(
      tag: tag,
      raw: offset..<(cursor + length),
      content: cursor..<(cursor + length)
    )
    offset = cursor + length
    return element
  }

  /// The raw encoding of one element.
  internal func data(of element: Element) -> Data {
    Data(bytes[element.raw])
  }
  /// The content octets of one element.
  internal func contentData(of element: Element) -> Data {
    Data(bytes[element.content])
  }

  /// The content as a small non-negative integer, or nil when it is
  /// longer than an Int carries.
  internal func integerValue(of element: Element) -> Int? {
    guard element.content.count <= MemoryLayout<Int>.size - 1 else {
      return nil
    }
    var value = 0
    for byte in bytes[element.content] {
      value = value << UInt8.bitWidth | Int(byte)
    }
    return value
  }
}
