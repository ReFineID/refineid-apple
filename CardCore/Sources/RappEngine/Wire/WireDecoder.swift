// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Decode one complete, strictly deterministic RAPP wire value.
///
/// Canonicality is settled by re-encoding the decoded value and requiring the
/// original bytes back, so a non-minimal argument or a mis-ordered map is
/// refused without a second set of rules to keep in step with the encoder.
internal func decodeDeterministicCbor(_ bytes: Data) throws -> WireValue {
  guard bytes.count <= WireLimits.framePlaintext else {
    throw WireError.oversizedPlaintext(got: bytes.count)
  }
  var decoder = WireDecoder(bytes: bytes)
  let value = try decoder.value(depth: 0)
  guard decoder.isAtEnd else { throw WireError.trailingData }
  guard try value.encoded() == bytes else { throw WireError.nonCanonical }
  return value
}

/// A bounded reader over untrusted bytes: every length is proved against the
/// input that remains before it is used to allocate or loop.
internal struct WireDecoder {
  /// Smallest encoding of one entry, used to bound a declared collection.
  private enum MinimumEntryBytes {
    static let array = 1
    static let map = 2
  }

  /// Bits in one byte, when an argument is read big-endian.
  private static let bitsPerByte: UInt64 = 8

  private let bytes: [UInt8]
  private var offset = 0

  internal var isAtEnd: Bool { offset == bytes.count }

  internal init(bytes: Data) {
    self.bytes = Array(bytes)
  }

  internal mutating func value(depth: Int) throws -> WireValue {
    guard depth <= WireLimits.nestingDepth else { throw WireError.nestingTooDeep }
    let initial = try byte()
    let major = initial >> WireValue.MajorType.shift
    let additional = initial & WireValue.MajorType.additionalInformationMask

    switch WireValue.MajorType(rawValue: major) {
    case .unsigned:
      return .unsigned(try argument(additional))

    case .negative:
      return try negative(additional)

    case .bytes:
      return .bytes(try take(try length(additional)))

    case .text:
      return .text(try text(additional))

    case .array:
      let count = try boundedCollectionLength(
        additional, minimumBytesPerEntry: MinimumEntryBytes.array)
      var items: [WireValue] = []
      items.reserveCapacity(count)
      for _ in 0..<count { items.append(try value(depth: depth + 1)) }
      return .array(items)

    case .map:
      return try map(additional, depth: depth)

    case .simple:
      return try simple(additional)

    case .none:
      throw WireError.forbiddenCborType
    }
  }

  /// The three simple values RAPP admits.
  private func simple(_ additional: UInt8) throws -> WireValue {
    switch additional {
    case WireValue.Simple.falseValue:
      return .boolean(false)

    case WireValue.Simple.trueValue:
      return .boolean(true)

    case WireValue.Simple.nullValue:
      return .null

    default:
      throw WireError.forbiddenCborType
    }
  }

  private mutating func negative(_ additional: UInt8) throws -> WireValue {
    let encoded = try argument(additional)
    guard encoded <= UInt64(Int64.max) else { throw WireError.integerOverflow }
    return .negative(-1 - Int64(encoded))
  }

  private mutating func text(_ additional: UInt8) throws -> String {
    let count = try length(additional)
    guard count <= WireLimits.textSize else { throw WireError.textTooLong(got: count) }
    guard let value = String(data: try take(count), encoding: .utf8) else {
      throw WireError.invalidUtf8
    }
    return value
  }

  private mutating func map(_ additional: UInt8, depth: Int) throws -> WireValue {
    let count = try boundedCollectionLength(
      additional, minimumBytesPerEntry: MinimumEntryBytes.map)
    var entries: [String: WireValue] = [:]
    for _ in 0..<count {
      guard case .text(let key) = try value(depth: depth + 1) else {
        throw WireError.nonTextMapKey
      }
      let entry = try value(depth: depth + 1)
      guard entries.updateValue(entry, forKey: key) == nil else {
        throw WireError.duplicateMapKey
      }
    }
    return .map(entries)
  }

  private mutating func byte() throws -> UInt8 {
    guard offset < bytes.count else { throw WireError.truncated }
    defer { offset += 1 }
    return bytes[offset]
  }

  private mutating func take(_ count: Int) throws -> Data {
    let (end, overflowed) = offset.addingReportingOverflow(count)
    guard !overflowed, end <= bytes.count else { throw WireError.truncated }
    defer { offset = end }
    return Data(bytes[offset..<end])
  }

  private mutating func length(_ additional: UInt8) throws -> Int {
    let value = try argument(additional)
    guard let count = Int(exactly: value) else { throw WireError.integerOverflow }
    return count
  }

  /// A collection length is only accepted once its minimum encoded size fits
  /// the bytes that remain, so a declared length cannot drive a long loop.
  private mutating func boundedCollectionLength(
    _ additional: UInt8, minimumBytesPerEntry: Int
  ) throws -> Int {
    let count = try length(additional)
    let (minimumBytes, overflowed) = count.multipliedReportingOverflow(by: minimumBytesPerEntry)
    guard !overflowed, minimumBytes <= bytes.count - offset else {
      throw WireError.collectionTooLarge(got: count)
    }
    return count
  }

  private mutating func argument(_ additional: UInt8) throws -> UInt64 {
    switch additional {
    case ...WireValue.Argument.immediateMaximum:
      return UInt64(additional)

    case WireValue.Argument.oneByte:
      return UInt64(try byte())

    case WireValue.Argument.twoBytes:
      return try bigEndian(byteCount: WireValue.Argument.twoByteWidth)

    case WireValue.Argument.fourBytes:
      return try bigEndian(byteCount: WireValue.Argument.fourByteWidth)

    case WireValue.Argument.eightBytes:
      return try bigEndian(byteCount: WireValue.Argument.eightByteWidth)

    default:
      throw WireError.forbiddenCborType
    }
  }

  private mutating func bigEndian(byteCount: Int) throws -> UInt64 {
    var value: UInt64 = 0
    for _ in 0..<byteCount { value = (value << Self.bitsPerByte) | UInt64(try byte()) }
    return value
  }
}
