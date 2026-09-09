// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

internal enum RappNoiseAndEnvelopeCorpusSupport {
  private enum Constants {
    static let majorAdditionalInfoMask: UInt8 = 0x1f
    static let majorLengthRange = 1...2
    static let maxDecodeDepth = 16
    static let maxCollectionCount = 128
    static let maxReadLength = 16_384
    static let pairLength = 2
    static let hexRadix = 16
    static let majorLengthMax: UInt8 = 23
    static let nextValue8bit: UInt8 = 24
    static let max8bit = UInt64(UInt8.max)
    static let nextValue16bit: UInt8 = 25
    static let min16bit: UInt64 = 0x100
    static let max16bit: UInt64 = 0xffff
    static let nextValue32bit: UInt8 = 26
    static let max32bit: UInt64 = 0xffff_ffff
    static let nextValue64bit: UInt8 = 27
    static let majorUnsigned = CBORMajor.unsigned.rawValue
    static let majorBytes = CBORMajor.bytes.rawValue
    static let majorText = CBORMajor.text.rawValue
    static let majorArray = CBORMajor.array.rawValue
    static let majorMap = CBORMajor.map.rawValue
    static let byteShift = 8
    static let byteCountUInt16 = 2
    static let byteCountUInt32 = 4
    static let byteCountUInt64 = 8
    static let wireMajor: UInt64 = 26
    static let wireMinor: UInt64 = 9
    static let sessionIDLength = 16
    static let challengeLength = 32
    static let hashPrefixLength = 16
  }

  private enum CBORMajor: UInt8 {
    case array = 4
    case bytes = 2
    case map = 5
    case text = 3
    case unsigned = 0
    case unusedForBitFlag = 1
  }

  internal enum CBORValue: Equatable {
    case array([Self])
    case bytes(Data)
    case map([String: Self])
    case text(String)
    case unsigned(UInt64)
  }

  internal enum CBORDecodeError: Error {
    case duplicateKey
    case invalidUTF8
    case limitExceeded
    case truncated
    case unsupported
  }

  internal struct Corpus: Decodable {
    // MARK: Nested Types

    internal enum CodingKeys: String, CodingKey {
      case noiseHandshake = "noise_handshake"
      case rejectedEnvelope = "rejected_envelope"
    }

    // MARK: Properties

    internal let noiseHandshake: [NoiseVector]
    internal let rejectedEnvelope: [RejectedEnvelopeVector]
  }

  internal struct NoiseVector: Decodable {
    // MARK: Nested Types

    internal enum CodingKeys: String, CodingKey {
      case name = "name"
      case suite = "suite"
      case transportProfile = "transport_profile"
      case handshakeHashHex = "handshake_hash_hex"
      case initiatorStaticPublicHex = "initiator_static_public_hex"
      case responderStaticPublicHex = "responder_static_public_hex"
      case messagesHex = "messages_hex"
      case prologueHex = "prologue_hex"
      case pairIDHex = "pair_id_hex"
      case sessionIDHex = "session_id_hex"
      case rendezvousTokenHex = "rendezvous_token_hex"
      case offerHashHex = "offer_hash_hex"
      case grantsHashHex = "grants_hash_hex"
      case testOnlyInitiatorEphemeralPrivateHex = "test_only_initiator_ephemeral_private_hex"
      case testOnlyInitiatorStaticPrivateHex = "test_only_initiator_static_private_hex"
      case testOnlyPairingSecretHex = "test_only_pairing_secret_hex"
      case testOnlyResponderEphemeralPrivateHex = "test_only_responder_ephemeral_private_hex"
      case testOnlyResponderStaticPrivateHex = "test_only_responder_static_private_hex"
    }

    // MARK: Properties

    internal let name: String
    internal let suite: String
    internal let transportProfile: String
    internal let handshakeHashHex: String
    internal let initiatorStaticPublicHex: String
    internal let responderStaticPublicHex: String
    internal let messagesHex: [String]
    internal let prologueHex: String
    internal let pairIDHex: String
    internal let sessionIDHex: String
    internal let rendezvousTokenHex: String?
    internal let offerHashHex: String?
    internal let grantsHashHex: String?
    internal let testOnlyInitiatorEphemeralPrivateHex: String
    internal let testOnlyInitiatorStaticPrivateHex: String
    internal let testOnlyPairingSecretHex: String?
    internal let testOnlyResponderEphemeralPrivateHex: String
    internal let testOnlyResponderStaticPrivateHex: String
  }

  internal struct RejectedEnvelopeVector: Decodable {
    // MARK: Nested Types

    internal enum CodingKeys: String, CodingKey {
      case name = "name"
      case error = "error"
      case canonicalCBORHex = "canonical_cbor_hex"
      case supportedCritical = "supported_critical"
    }

    // MARK: Properties

    internal let name: String
    internal let canonicalCBORHex: String
    internal let error: String
    internal let supportedCritical: [String]
  }

  internal struct BoundedCBORDecoder {
    // MARK: Properties

    private let bytes: [UInt8]
    private var offset = 0

    // MARK: Computed Properties

    internal var isAtEnd: Bool { offset == bytes.count }

    // MARK: Lifecycle

    internal init(data: Data) {
      bytes = Array(data)
    }

    // MARK: Functions

    internal mutating func decode(depth: Int = 0) throws -> CBORValue {
      guard depth < Constants.maxDecodeDepth else { throw CBORDecodeError.limitExceeded }
      let initial = try readByte()
      let major = initial >> 5
      let count = try readLength(initial & Constants.majorAdditionalInfoMask)

      switch major {
      case Constants.majorUnsigned:
        return .unsigned(count)

      case Constants.majorBytes:
        return .bytes(try readData(count))

      case Constants.majorText:
        let data = try readData(count)
        guard let value = String(data: data, encoding: .utf8) else {
          throw CBORDecodeError.invalidUTF8
        }
        return .text(value)

      case Constants.majorArray:
        guard count <= UInt64(Constants.maxCollectionCount) else {
          throw CBORDecodeError.limitExceeded
        }
        return .array(try (0..<Int(count)).map { _ in try decode(depth: depth + 1) })

      case Constants.majorMap:
        guard count <= UInt64(Constants.maxCollectionCount) else {
          throw CBORDecodeError.limitExceeded
        }
        var result: [String: CBORValue] = [:]
        for _ in 0..<Int(count) {
          guard case .text(let key) = try decode(depth: depth + 1) else {
            throw CBORDecodeError.unsupported
          }
          guard result[key] == nil else { throw CBORDecodeError.duplicateKey }
          result[key] = try decode(depth: depth + 1)
        }
        return .map(result)

      default:
        throw CBORDecodeError.unsupported
      }
    }

    private mutating func readLength(_ additional: UInt8) throws -> UInt64 {
      switch additional {
      case 0...Constants.majorLengthMax:
        return UInt64(additional)

      case Constants.nextValue8bit:
        return UInt64(try readByte())

      case Constants.nextValue16bit:
        return try readBigEndian(byteCount: Constants.byteCountUInt16)

      case Constants.nextValue32bit:
        return try readBigEndian(byteCount: Constants.byteCountUInt32)

      case Constants.nextValue64bit:
        return try readBigEndian(byteCount: Constants.byteCountUInt64)

      default:
        throw CBORDecodeError.unsupported
      }
    }

    private mutating func readBigEndian(byteCount: Int) throws -> UInt64 {
      var value: UInt64 = 0
      for _ in 0..<byteCount {
        value = (value << Constants.byteShift) | UInt64(try readByte())
      }
      return value
    }

    private mutating func readByte() throws -> UInt8 {
      guard offset < bytes.count else { throw CBORDecodeError.truncated }
      defer { offset += 1 }
      return bytes[offset]
    }

    private mutating func readData(_ count: UInt64) throws -> Data {
      guard
        count <= Constants.maxReadLength,
        count <= UInt64(bytes.count - offset)
      else {
        throw CBORDecodeError.limitExceeded
      }
      let end = offset + Int(count)
      defer { offset = end }
      return Data(bytes[offset..<end])
    }
  }

  internal static let wire: (major: UInt64, minor: UInt64) = (
    major: Constants.wireMajor,
    minor: Constants.wireMinor
  )

  internal static func encodeUnsigned(_ value: UInt64) -> Data {
    encodeMajor(Constants.majorUnsigned, value: value)
  }

  internal static func encodeBytes(_ value: Data) -> Data {
    var result = encodeMajor(Constants.majorBytes, value: UInt64(value.count))
    result.append(value)
    return result
  }

  internal static func encodeText(_ value: String) -> Data {
    let utf8 = Data(value.utf8)
    var result = encodeMajor(Constants.majorText, value: UInt64(utf8.count))
    result.append(utf8)
    return result
  }

  internal static func encodeArray(_ values: [Data]) -> Data {
    var result = encodeMajor(Constants.majorArray, value: UInt64(values.count))
    values.forEach { result.append($0) }
    return result
  }

  internal static func encodeHex(_ value: Data) -> String {
    value.map { String(format: "%02x", $0) }.joined()
  }

  internal static func decodeHex(_ value: String) -> Data {
    decodedHex(value)
  }

  private static func decodedHex(_ value: String) -> Data {
    precondition(
      value.count.isMultiple(of: Constants.pairLength),
      "Odd hex length")
    var result = Data()
    result.reserveCapacity(value.count / Constants.pairLength)
    var index = value.startIndex
    while index < value.endIndex {
      let next = value.index(index, offsetBy: Constants.pairLength)
      guard let byte = UInt8(value[index..<next], radix: Constants.hexRadix) else {
        preconditionFailure("Invalid hex")
      }
      result.append(byte)
      index = next
    }
    return result
  }

  private static func encodeMajor(_ major: UInt8, value: UInt64) -> Data {
    let prefix = major << 5
    switch value {
    case 0...UInt64(Constants.majorLengthMax):
      return Data([prefix | UInt8(value)])

    case UInt64(Constants.nextValue8bit)...Constants.max8bit:
      return Data([prefix | UInt8(Constants.nextValue8bit), UInt8(value)])

    case UInt64(Constants.min16bit)...Constants.max16bit:
      return Data([
        prefix | UInt8(Constants.nextValue16bit),
        UInt8(value >> UInt8(Constants.byteShift)),
        UInt8(value),
      ])

    case UInt64(Constants.nextValue32bit)...Constants.max32bit:
      return Data(
        [prefix | UInt8(Constants.nextValue32bit)]
          + (0..<Constants.byteCountUInt32).reversed().map {
            UInt8(value >> UInt64($0 * Constants.byteShift))
          })

    default:
      return Data(
        [prefix | UInt8(Constants.nextValue64bit)]
          + (0..<Constants.byteCountUInt64).reversed().map {
            UInt8(value >> UInt64($0 * Constants.byteShift))
          })
    }
  }

  internal static func corpus(
    from repositoryRoot: URL
  ) throws -> Corpus {
    let url =
      repositoryRoot
      .appendingPathComponent("Documentation")
      .appendingPathComponent("rapp-conformance")
      .appendingPathComponent("rapp-v26.9.7.70.json")
    return try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
  }

  internal static func deriveIdentifier(domain: String, handshakeHash: Data) -> String {
    var input = Data(domain.utf8)
    input.append(handshakeHash)
    return encodeHex(Data(SHA256.hash(data: input)).prefix(Constants.hashPrefixLength))
  }

  internal static func validateEnvelope(
    _ value: CBORValue,
    supportedCritical: Set<String>
  ) -> String? {
    guard case .map(let envelope) = value else { return "WrongType { field: \"envelope\" }" }
    let allowed: Set<String> = [
      "version", "session_id", "sequence", "type", "body", "critical", "extensions",
    ]
    guard Set(envelope.keys).isSubset(of: allowed) else { return "UnknownField" }

    guard let version = envelope["version"] else { return "MissingField { field: \"version\" }" }
    guard case .array(let parts) = version,
      parts.count == Constants.majorLengthRange.count,
      case .unsigned(let major) = parts[0],
      case .unsigned(let minor) = parts[1]
    else { return "WrongType { field: \"version\" }" }
    guard major == wire.major, minor == wire.minor else { return "UnsupportedVersion" }

    guard case .bytes(let sessionID)? = envelope["session_id"] else {
      return "WrongType { field: \"session_id\" }"
    }
    guard sessionID.count == Constants.sessionIDLength else {
      return "WrongLength { field: \"session_id\", expected: 16, got: \(sessionID.count) }"
    }
    guard case .unsigned? = envelope["sequence"] else { return "WrongType { field: \"sequence\" }" }
    guard case .text(let type)? = envelope["type"] else { return "WrongType { field: \"type\" }" }
    guard type == "liveness.ping" else { return "UnknownMessageType" }
    guard case .map(let body)? = envelope["body"] else {
      return "WrongType { field: \"body\" }"
    }
    guard
      case .bytes(let challenge)? = body["challenge"],
      challenge.count == Constants.challengeLength,
      case .unsigned? = body["last_received_sequence"]
    else { return "WrongType { field: \"body\" }" }

    var critical: [String] = []
    if let criticalValue = envelope["critical"] {
      guard case .array(let entries) = criticalValue else {
        return "WrongType { field: \"critical\" }"
      }
      for entry in entries {
        guard case .text(let name) = entry else {
          return "WrongType { field: \"critical\" }"
        }
        critical.append(name)
      }
    }

    var extensions: [String: CBORValue] = [:]
    if let extensionsValue = envelope["extensions"] {
      guard case .map(let entries) = extensionsValue else {
        return "WrongType { field: \"extensions\" }"
      }
      extensions = entries
    }
    guard critical.allSatisfy({ extensions[$0] != nil }) else {
      return "CriticalExtensionMissing"
    }
    guard critical.allSatisfy(supportedCritical.contains) else {
      return "UnsupportedCriticalExtension"
    }
    return nil
  }

  internal static func validateVectorHex(_ value: String) -> Data {
    decodedHex(value)
  }
}
