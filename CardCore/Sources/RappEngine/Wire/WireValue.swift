// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The restricted value space RAPP encodes, in RFC 8949 core deterministic
/// form.
///
/// Nothing outside these cases is representable, so an encoder cannot emit a
/// type the peer is required to reject.
internal enum WireValue: Equatable, Sendable {
  case array([Self])
  case boolean(Bool)
  case bytes(Data)
  case map([String: Self])
  case negative(Int64)
  case null
  case text(String)
  case unsigned(UInt64)

  internal enum MajorType: UInt8 {
    case array = 4
    case bytes = 2
    case map = 5
    case negative = 1
    case simple = 7
    case text = 3
    case unsigned = 0

    /// Bits an initial byte is shifted by to leave the major type.
    internal static let shift: UInt8 = 5

    /// Mask selecting the additional information in an initial byte.
    internal static let additionalInformationMask: UInt8 = 31
  }

  /// Additional-information values that carry the argument out of line.
  internal enum Argument {
    internal static let immediateMaximum: UInt8 = 23
    internal static let oneByte: UInt8 = 24
    internal static let twoBytes: UInt8 = 25
    internal static let fourBytes: UInt8 = 26
    internal static let eightBytes: UInt8 = 27

    /// Byte counts each out-of-line argument form carries.
    internal static let twoByteWidth = 2
    internal static let fourByteWidth = 4
    internal static let eightByteWidth = 8

    /// Exclusive upper bounds for each argument form.
    internal static let oneByteBound: UInt64 = 256
    internal static let twoByteBound: UInt64 = 65_536
    internal static let fourByteBound: UInt64 = 4_294_967_296
  }

  /// Simple values RAPP admits.
  internal enum Simple {
    internal static let falseValue: UInt8 = 20
    internal static let trueValue: UInt8 = 21
    internal static let nullValue: UInt8 = 22
  }

  internal static func header(_ major: MajorType, _ value: UInt64) -> Data {
    let prefix = major.rawValue << MajorType.shift
    switch value {
    case ..<UInt64(Argument.oneByte):
      return Data([prefix | UInt8(value)])

    case ..<Argument.oneByteBound:
      return Data([prefix | Argument.oneByte, UInt8(value)])

    case ..<Argument.twoByteBound:
      return Data([prefix | Argument.twoBytes])
        + withUnsafeBytes(of: UInt16(value).bigEndian) { Data($0) }

    case ..<Argument.fourByteBound:
      return Data([prefix | Argument.fourBytes])
        + withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) }

    default:
      return Data([prefix | Argument.eightBytes])
        + withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
  }

  private static func simpleByte(_ value: UInt8) -> Data {
    Data([(MajorType.simple.rawValue << MajorType.shift) | value])
  }

  /// Deterministic encoding, or the reason the value cannot be encoded.
  internal func encoded() throws -> Data {
    try encoded(depth: 0)
  }

  private func encoded(depth: Int) throws -> Data {
    guard depth <= WireLimits.nestingDepth else { throw WireError.nestingTooDeep }
    switch self {
    case .array(let items):
      var output = Self.header(.array, UInt64(items.count))
      for item in items {
        output += try item.encoded(depth: depth + 1)
      }
      return output

    case .map(let entries):
      return try encodedMap(entries, depth: depth)

    default:
      return try encodedScalar()
    }
  }

  /// Every value that carries no nested value of its own.
  private func encodedScalar() throws -> Data {
    switch self {
    case .boolean(let value):
      return Self.simpleByte(value ? Simple.trueValue : Simple.falseValue)

    case .bytes(let value):
      return Self.header(.bytes, UInt64(value.count)) + value

    case .negative(let value):
      guard value < 0 else { throw WireError.invalidValue(field: "integer") }
      // -1 - value is the CBOR argument; in two's complement that is ~value,
      // which cannot overflow at the minimum representable integer.
      return Self.header(.negative, UInt64(bitPattern: ~Int64(value)))

    case .null:
      return Self.simpleByte(Simple.nullValue)

    case .text(let value):
      let utf8 = Data(value.utf8)
      guard utf8.count <= WireLimits.textSize else {
        throw WireError.textTooLong(got: utf8.count)
      }
      return Self.header(.text, UInt64(utf8.count)) + utf8

    case .unsigned(let value):
      return Self.header(.unsigned, value)

    default:
      throw WireError.forbiddenCborType
    }
  }

  /// Encodes a map in RFC 8949 order.
  ///
  /// Entries are ordered by their encoded key, shorter first and then
  /// bytewise. That is not the same as ordering the key strings.
  private func encodedMap(_ entries: [String: Self], depth: Int) throws -> Data {
    var output = Self.header(.map, UInt64(entries.count))
    let ordered =
      try entries
      .map { (key: try Self.text($0.key).encoded(depth: depth + 1), value: $0.value) }
      .sorted { left, right in
        left.key.count == right.key.count
          ? left.key.lexicographicallyPrecedes(right.key)
          : left.key.count < right.key.count
      }
    for entry in ordered {
      output += entry.key
      output += try entry.value.encoded(depth: depth + 1)
    }
    return output
  }
}
