// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension RappConformanceCorpusSupport {
  // MARK: Nested Types

  internal enum DeterministicCBOR {
    internal static func encode(_ value: CorpusValue) throws -> Data {
      switch value {
      case .unsigned(let number):
        return header(major: Constants.majorUnsigned, value: number)

      case .negative(let number):
        guard number < 0 else { throw CorpusError.invalidNegative }
        return header(major: Constants.majorNegative, value: UInt64(-(number + 1)))

      case .bytes(let bytes):
        return header(major: Constants.majorBytes, value: UInt64(bytes.count)) + bytes

      case .text(let text):
        let bytes = Data(text.utf8)
        return header(major: Constants.majorText, value: UInt64(bytes.count)) + bytes

      case .array(let items):
        return try items.reduce(header(major: Constants.majorArray, value: UInt64(items.count))) {
          accumulator, item in
          try accumulator + encode(item)
        }

      case .map(let entries):
        var seen = Set<Data>()
        let encodedEntries = try entries.map { entry -> (Data, Data) in
          let key = try encode(.text(entry.key))
          guard seen.insert(key).inserted else { throw CorpusError.duplicateMapKey }
          return try (key, encode(entry.value))
        }
        .sorted { left, right in
          left.0.lexicographicallyPrecedes(right.0)
        }
        return encodedEntries.reduce(
          header(major: Constants.majorMap, value: UInt64(entries.count))
        ) { accumulator, entry in
          accumulator + entry.0 + entry.1
        }

      case .bool(let value):
        return Data([value ? Constants.boolTrue : Constants.boolFalse])

      case .null:
        return Data([Constants.cborNull])
      }
    }

    private static func header(major: UInt8, value: UInt64) -> Data {
      let prefix = major << 5
      switch value {
      case 0...Constants.compactValueLimit:
        return Data([prefix | UInt8(value)])

      case UInt64(Constants.cborLength8Bit)...Constants.cborLength8BitMax:
        return Data([prefix | UInt8(Constants.cborLength8Bit), UInt8(value)])

      case 0...Constants.cborLength16BitMax:
        var integer = UInt16(value).bigEndian
        return Data([prefix | UInt8(Constants.cborLength16Bit)])
          + withUnsafeBytes(of: &integer) { Data($0) }

      case 0...Constants.cborLength32BitMax:
        var integer = UInt32(value).bigEndian
        return Data([prefix | UInt8(Constants.cborLength32Bit)])
          + withUnsafeBytes(of: &integer) { Data($0) }

      default:
        var integer = value.bigEndian
        return Data([prefix | UInt8(Constants.cborLength64Bit)])
          + withUnsafeBytes(of: &integer) { Data($0) }
      }
    }
  }
}
