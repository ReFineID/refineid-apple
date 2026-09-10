// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension RappNoiseAndEnvelopeCorpusSupport {
  // MARK: Nested Types

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

    internal mutating func decode(depth: Int) throws -> CBORValue {
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
        return try decodeArray(count: count, depth: depth)

      case Constants.majorMap:
        return try decodeMap(count: count, depth: depth)

      default:
        throw CBORDecodeError.unsupported
      }
    }

    private mutating func decodeArray(count: UInt64, depth: Int) throws -> CBORValue {
      guard count <= UInt64(Constants.maxCollectionCount) else {
        throw CBORDecodeError.limitExceeded
      }
      return .array(try (0..<Int(count)).map { _ in try decode(depth: depth + 1) })
    }

    private mutating func decodeMap(count: UInt64, depth: Int) throws -> CBORValue {
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
}
