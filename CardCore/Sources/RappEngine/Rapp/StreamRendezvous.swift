// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Why a dialing proxy opened this stream connection.
///
/// The preamble is the first frame and is sent in the clear, so every failure
/// here is pre-authentication invalid input: the connection closes and no
/// stored state changes.
internal enum StreamRendezvous: Equatable {
  case pairing
  case session(token: Data)

  internal enum Failure: Error, Equatable, CustomStringConvertible {
    case malformed
    case oversized
    case unknownPurpose

    internal var description: String {
      switch self {
      case .malformed:
        "Malformed"

      case .oversized:
        "Oversized"

      case .unknownPurpose:
        "UnknownPurpose"
      }
    }
  }

  private static let domain = "RAPP-stream-v1"
  private static let pairingPurpose = "pairing"
  private static let sessionPurpose = "session"

  /// Positions of the three elements in an encoded preamble.
  private static let domainIndex = 0
  private static let purposeIndex = 1
  private static let tokenIndex = 2
  private static let elementCount = 3

  /// Length of the token naming which stored pairing a session answers.
  internal static let tokenSize = 16

  /// Upper bound on an encoded preamble frame.
  internal static let maximumFrameSize = 64

  internal static func decode(_ bytes: Data) throws -> Self {
    guard bytes.count <= maximumFrameSize else { throw Failure.oversized }
    guard case .array(let elements) = try? decodeDeterministicCbor(bytes),
      elements.count == elementCount,
      case .text(let domain) = elements[Self.domainIndex],
      case .text(let purpose) = elements[Self.purposeIndex],
      case .bytes(let token) = elements[Self.tokenIndex],
      domain == Self.domain
    else { throw Failure.malformed }

    switch purpose {
    case pairingPurpose:
      guard token.isEmpty else { throw Failure.malformed }
      return .pairing

    case sessionPurpose:
      guard token.count == tokenSize else { throw Failure.malformed }
      return .session(token: token)

    default:
      throw Failure.unknownPurpose
    }
  }

  internal func encoded() throws -> Data {
    let purpose: String
    let token: Data
    switch self {
    case .pairing:
      purpose = Self.pairingPurpose
      token = Data()

    case .session(let value):
      purpose = Self.sessionPurpose
      token = value
    }
    let value = WireValue.array([.text(Self.domain), .text(purpose), .bytes(token)])
    guard let encoded = try? value.encoded() else { throw Failure.malformed }
    return encoded
  }
}
