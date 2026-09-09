// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Walking the tag-length-value records a travel document uses.
///
/// ICAO's files are BER, and several of their tags take the two-byte
/// form: the LDS version, the Unicode version and the displayed
/// signature image all announce themselves that way. A reader that
/// takes one byte as the tag reads the second as a length, walks off
/// by one, and parses nonsense confidently - EF.COM's data-group list
/// simply disappears and the card is reported to carry nothing, which
/// is what happened before this existed.
///
/// It is separate from `DerReader` on purpose: that is a DER walker
/// for the PKCS#15 side and has no reason to grow BER's tag forms.
internal struct IcaoTlv {
  /// One record: which tag introduced it, and where its content sits.
  internal struct Record {
    /// The byte that names the record - the whole tag when it is one
    /// byte, the second byte when it is two.
    internal let tag: UInt8

    /// Whether the tag took the two-byte form.
    internal let hasTwoByteTag: Bool

    /// The content octets.
    internal let content: Range<Int>

    /// Where the next record begins.
    internal let end: Int
  }

  /// The file's octets.
  private let bytes: [UInt8]

  /// The whole file as one record, when it is one.
  internal var outermost: Record? {
    self.record(at: bytes.startIndex)
  }

  /// Walks one file's content.
  internal init(_ content: Data) {
    self.bytes = Array(content)
  }

  /// One record's content, copied out.
  internal func content(of record: Record) -> Data {
    Data(bytes[record.content])
  }

  /// The records directly inside `range`.
  internal func records(within range: Range<Int>) -> [Record] {
    var found: [Record] = []
    var cursor = range.lowerBound
    while cursor < range.upperBound {
      guard let record = self.record(at: cursor),
        record.end > cursor
      else {
        break
      }
      found.append(record)
      cursor = record.end
    }
    return found
  }

  /// One record beginning at `offset`.
  internal func record(at offset: Int) -> Record? {
    guard offset < bytes.count else { return nil }
    let hasTwoByteTag = bytes[offset] == BerValues.twoByteTagIntroducer
    let tagLength =
      hasTwoByteTag ? BerValues.twoByteTagLength : BerValues.oneByteTagLength
    guard offset + tagLength <= bytes.count else { return nil }
    guard
      let content = self.contentRange(from: offset + tagLength)
    else {
      return nil
    }
    return Record(
      tag: bytes[offset + tagLength - 1],
      hasTwoByteTag: hasTwoByteTag,
      content: content,
      end: content.upperBound
    )
  }

  /// The content of an element whose length octets start at `offset`.
  private func contentRange(from offset: Int) -> Range<Int>? {
    guard offset < bytes.count else { return nil }
    let first = bytes[offset]
    var start = offset + BerValues.lengthIntroducerLength
    var length = Int(first)
    if first & BerValues.longFormFlag != 0 {
      let octets = Int(first & BerValues.longFormCountMask)
      guard
        octets > 0, octets <= BerValues.longFormMaximumOctets,
        start + octets <= bytes.count
      else { return nil }
      length = 0
      for index in start..<(start + octets) {
        length = length << UInt8.bitWidth | Int(bytes[index])
      }
      start += octets
    }
    guard start + length <= bytes.count else { return nil }
    return start..<(start + length)
  }
}
