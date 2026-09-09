// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// Constants and derivations the specification fixes for RAPP's handshakes.
internal enum RappNoise {
  internal static let wireVersion: (major: UInt64, minor: UInt64) = (26, 9)

  internal static let pairingSuite = "Noise_XXpsk3_25519_ChaChaPoly_SHA256"
  internal static let sessionSuite = "Noise_KK_25519_ChaChaPoly_SHA256"

  private static let pairingPrologueDomain = "RAPP-pairing-v1"
  private static let sessionPrologueDomain = "RAPP-session-v1"

  private static let sessionIdentifierDomain = "RAPP-session-id-v1"
  private static let pairIdentifierDomain = "RAPP-pair-id-v1"
  private static let rendezvousDomain = "RAPP-rendezvous-v1"

  /// Identifiers are the leading half of a domain-separated transcript hash.
  private static let identifierLength = 16

  private static var versionValue: WireValue {
    .array([.unsigned(wireVersion.major), .unsigned(wireVersion.minor)])
  }

  /// Binds the pairing handshake to the offer it answers.
  internal static func pairingPrologue(offerHash: Data, transportProfile: String) throws -> Data {
    let value = WireValue.array([
      .text(pairingPrologueDomain),
      versionValue,
      .text(pairingSuite),
      .bytes(offerHash),
      .text(transportProfile),
    ])
    return try value.encoded()
  }

  /// Binds the session handshake to the pairing and the agreed grants.
  internal static func sessionPrologue(
    pairIdentifier: Data, grantsHash: Data, transportProfile: String
  ) throws -> Data {
    let value = WireValue.array([
      .text(sessionPrologueDomain),
      versionValue,
      .text(sessionSuite),
      .bytes(pairIdentifier),
      .bytes(grantsHash),
      .text(transportProfile),
    ])
    return try value.encoded()
  }

  private static func identifier(domain: String, handshakeHash: Data) -> Data {
    Data(SHA256.hash(data: Data(domain.utf8) + handshakeHash).prefix(identifierLength))
  }

  internal static func sessionIdentifier(handshakeHash: Data) -> Data {
    identifier(domain: sessionIdentifierDomain, handshakeHash: handshakeHash)
  }

  internal static func pairIdentifier(handshakeHash: Data) -> Data {
    identifier(domain: pairIdentifierDomain, handshakeHash: handshakeHash)
  }

  internal static func rendezvousToken(handshakeHash: Data) -> Data {
    identifier(domain: rendezvousDomain, handshakeHash: handshakeHash)
  }
}
