// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

internal enum RappConformanceCorpusSupport {

  private enum CBORMajor: UInt8 {
    case array = 4
    case bytes = 2
    case map = 5
    case negative = 1
    case text = 3
    case unsigned = 0
  }

  internal enum Constants {
    internal static let majorUnsigned = CBORMajor.unsigned.rawValue
    internal static let majorNegative = CBORMajor.negative.rawValue
    internal static let majorBytes = CBORMajor.bytes.rawValue
    internal static let majorText = CBORMajor.text.rawValue
    internal static let majorArray = CBORMajor.array.rawValue
    internal static let majorMap = CBORMajor.map.rawValue
    internal static let compactValueLimit: UInt64 = 23
    internal static let utf8HexDigitsPerByte = 2
    internal static let prefixLength = 8
    internal static let hexRadix = 16
    internal static let hexPairLength = 2
    internal static let cborLength8Bit = 24
    internal static let cborLength16Bit = 25
    internal static let cborLength32Bit = 26
    internal static let cborLength64Bit = 27
    internal static let boolFalse = Self.byte(fromHex: "f4")
    internal static let boolTrue = Self.byte(fromHex: "f5")
    internal static let cborNull = Self.byte(fromHex: "f6")
    internal static let cborLength8BitMax = UInt64(UInt8.max)
    internal static let cborLength16BitMax = UInt64(UInt16.max)
    internal static let cborLength32BitMax = UInt64(UInt32.max)
    internal static let nibbleShift: UInt8 = 4
    internal static let zeroDigit: UInt8 = 48
    internal static let nineDigit: UInt8 = 57
    internal static let upperADigit: UInt8 = 65
    internal static let upperFDigit: UInt8 = 70
    internal static let lowerADigit: UInt8 = 97
    internal static let lowerFDigit: UInt8 = 102
    internal static let upperOffset: UInt8 = 55
    internal static let lowerOffset: UInt8 = 87
    internal static let hexPrefix = 4

    private static func byte(fromHex value: String) -> UInt8 {
      guard let byte = UInt8(value, radix: Self.hexRadix) else {
        preconditionFailure("Invalid CBOR byte literal \(value)")
      }
      return byte
    }
  }

  // MARK: Nested Types

  private enum CorpusValueKeys: String, CodingKey {
    case entries = "entries"
    case hex = "hex"
    case items = "items"
    case kind = "kind"
    case value = "value"
  }

  internal indirect enum CorpusValue: Decodable {
    case array([Self])
    case bool(Bool)
    case bytes(Data)
    case map([CorpusMapEntry])
    case negative(Int64)
    case null
    case text(String)
    case unsigned(UInt64)

    // MARK: Lifecycle

    internal init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CorpusValueKeys.self)
      switch try container.decode(String.self, forKey: .kind) {
      case "unsigned":
        self = try .unsigned(container.decode(UInt64.self, forKey: .value))

      case "negative":
        self = try .negative(container.decode(Int64.self, forKey: .value))

      case "bytes":
        self = try .bytes(Self.data(fromHex: container.decode(String.self, forKey: .hex)))

      case "text":
        self = try .text(container.decode(String.self, forKey: .value))

      case "array":
        self = try .array(container.decode([Self].self, forKey: .items))

      case "map":
        self = try .map(container.decode([CorpusMapEntry].self, forKey: .entries))

      case "bool":
        self = try .bool(container.decode(Bool.self, forKey: .value))

      case "null":
        self = .null

      case let kind:
        throw DecodingError.dataCorruptedError(
          forKey: .kind,
          in: container,
          debugDescription: "Unknown corpus value kind \(kind)"
        )
      }
    }

    internal static func data(fromHex value: String) throws -> Data {
      try RappConformanceCorpusSupport.data(fromHex: value)
    }
  }

  internal struct CorpusMapEntry: Decodable {
    internal let key: String
    internal let value: CorpusValue
  }

  internal enum CorpusError: Error {
    case duplicateMapKey
    case invalidHex
    case invalidNegative
  }

  internal static func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
  }

  internal static func data(fromHex value: String) throws -> Data {
    let characters = Array(value.utf8)
    guard characters.count.isMultiple(of: Constants.hexPairLength) else {
      throw CorpusError.invalidHex
    }
    var result = Data()
    result.reserveCapacity(characters.count / Constants.hexPairLength)
    for index in stride(
      from: 0,
      to: characters.count,
      by: Constants.hexPairLength
    ) {
      guard
        let high = hexNibble(characters[index]),
        let low = hexNibble(characters[index + 1])
      else {
        throw CorpusError.invalidHex
      }
      result.append((high << Constants.nibbleShift) | low)
    }
    return result
  }

  private static func hexNibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case Constants.zeroDigit...Constants.nineDigit:
      return byte - UInt8(Constants.zeroDigit)

    case Constants.upperADigit...Constants.upperFDigit:
      return byte - UInt8(Constants.upperOffset)

    case Constants.lowerADigit...Constants.lowerFDigit:
      return byte - UInt8(Constants.lowerOffset)

    default:
      return nil
    }
  }
}
