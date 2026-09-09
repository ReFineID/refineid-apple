// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

internal enum RappConformanceCorpusSupport {
  private enum Constants {
    private enum CBORMajor: UInt8 {
      case array = 4
      case bytes = 2
      case map = 5
      case negative = 1
      case text = 3
      case unsigned = 0
    }

    static let majorUnsigned = CBORMajor.unsigned.rawValue
    static let majorNegative = CBORMajor.negative.rawValue
    static let majorBytes = CBORMajor.bytes.rawValue
    static let majorText = CBORMajor.text.rawValue
    static let majorArray = CBORMajor.array.rawValue
    static let majorMap = CBORMajor.map.rawValue
    static let compactValueLimit: UInt64 = 23
    static let utf8HexDigitsPerByte = 2
    static let prefixLength = 8
    static let hexRadix = 16
    static let hexPairLength = 2
    static let cborLength8Bit = 24
    static let cborLength16Bit = 25
    static let cborLength32Bit = 26
    static let cborLength64Bit = 27
    static let boolFalse = Self.byte(fromHex: "f4")
    static let boolTrue = Self.byte(fromHex: "f5")
    static let cborNull = Self.byte(fromHex: "f6")
    static let cborLength8BitMax = UInt64(UInt8.max)
    static let cborLength16BitMax = UInt64(UInt16.max)
    static let cborLength32BitMax = UInt64(UInt32.max)
    static let nibbleShift: UInt8 = 4
    static let zeroDigit: UInt8 = 48
    static let nineDigit: UInt8 = 57
    static let upperADigit: UInt8 = 65
    static let upperFDigit: UInt8 = 70
    static let lowerADigit: UInt8 = 97
    static let lowerFDigit: UInt8 = 102
    static let upperOffset: UInt8 = 55
    static let lowerOffset: UInt8 = 87
    static let hexPrefix = 4

    private static func byte(fromHex value: String) -> UInt8 {
      guard let byte = UInt8(value, radix: Self.hexRadix) else {
        preconditionFailure("Invalid CBOR byte literal \(value)")
      }
      return byte
    }
  }

  internal struct Corpus: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case format = "format"
      case protocolDocumentVersion = "protocol_document_version"
      case deterministicCBOR = "deterministic_cbor"
      case identifierDerivation = "identifier_derivation"
      case grantsHash = "grants_hash"
      case requestHash = "request_hash"
      case rejectedCBOR = "rejected_cbor"
      case streamRendezvous = "stream_rendezvous"
    }

    // MARK: Properties

    internal let format: String
    internal let protocolDocumentVersion: String
    internal let deterministicCBOR: [CBORVector]
    internal let identifierDerivation: [IdentifierVector]
    internal let grantsHash: [GrantsVector]
    internal let requestHash: [RequestVector]
    internal let rejectedCBOR: [RejectedCBORVector]
    internal let streamRendezvous: [StreamRendezvousVector]
  }

  internal struct CBORVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case value = "value"
      case encodedHex = "encoded_hex"
    }

    // MARK: Properties

    internal let name: String
    internal let value: CorpusValue
    internal let encodedHex: String
  }

  internal struct IdentifierVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case handshakeHashHex = "handshake_hash_hex"
      case pairIDHex = "pair_id_hex"
      case sessionIDHex = "session_id_hex"
      case rendezvousTokenHex = "rendezvous_token_hex"
    }

    // MARK: Properties

    internal let name: String
    internal let handshakeHashHex: String
    internal let pairIDHex: String
    internal let sessionIDHex: String
    internal let rendezvousTokenHex: String
  }

  internal struct StreamRendezvousVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case accepted = "accepted"
      case purpose = "purpose"
      case encodedHex = "encoded_hex"
      case rendezvousTokenHex = "rendezvous_token_hex"
      case error = "error"
    }

    // MARK: Properties

    internal let name: String
    internal let accepted: Bool
    internal let purpose: String
    internal let encodedHex: String
    internal let rendezvousTokenHex: String?
    internal let error: String?
  }

  internal struct GrantsVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case profiles = "profiles"
      case canonicalCBORHex = "canonical_cbor_hex"
      case sha256Hex = "sha256_hex"
    }

    // MARK: Properties

    internal let name: String
    internal let profiles: [String]
    internal let canonicalCBORHex: String
    internal let sha256Hex: String
  }

  internal struct RequestVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case sessionIDHex = "session_id_hex"
      case operationIDHex = "operation_id_hex"
      case profile = "profile"
      case action = "action"
      case context = "context"
      case payload = "payload"
      case preimageCBORHex = "preimage_cbor_hex"
      case sha256Hex = "sha256_hex"
    }

    // MARK: Properties

    internal let name: String
    internal let sessionIDHex: String
    internal let operationIDHex: String
    internal let profile: String
    internal let action: String
    internal let context: CorpusValue
    internal let payload: CorpusValue
    internal let preimageCBORHex: String
    internal let sha256Hex: String
  }

  internal struct RejectedCBORVector: Decodable {
    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case name = "name"
      case encodedHex = "encoded_hex"
      case error = "error"
    }

    // MARK: Properties

    internal let name: String
    internal let encodedHex: String
    internal let error: String
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

    // MARK: Nested Types

    private enum CodingKeys: String, CodingKey {
      case entries = "entries"
      case hex = "hex"
      case items = "items"
      case kind = "kind"
      case value = "value"
    }

    // MARK: Lifecycle

    internal init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
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
          try $0 + encode($1)
        }

      case .map(let entries):
        var seen = Set<Data>()
        let encodedEntries = try entries.map { entry -> (Data, Data) in
          let key = try encode(.text(entry.key))
          guard seen.insert(key).inserted else { throw CorpusError.duplicateMapKey }
          return try (key, encode(entry.value))
        }.sorted { left, right in
          left.0.lexicographicallyPrecedes(right.0)
        }
        return encodedEntries.reduce(
          header(major: Constants.majorMap, value: UInt64(entries.count))
        ) {
          $0 + $1.0 + $1.1
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
