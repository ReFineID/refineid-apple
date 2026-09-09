// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The key algorithm behind an SCS signature, as the protocol names it.
///
/// The response's `signatureAlgorithm` field composes the digest and
/// key names in the `SHA256withRSA` Java convention (DVV SCS
/// specification v1.3 §2.6.3).
public enum ScsKeyAlgorithm: Equatable, Sendable {
  /// An elliptic-curve card key.
  case ecdsa

  /// An RSA card key.
  case rsa

  /// The protocol's digest-name spelling for `hash`.
  public static func scsName(hash: SigningHash) -> String {
    switch hash {
    case .sha1:
      "SHA1"

    case .sha224:
      "SHA224"

    case .sha256:
      "SHA256"

    case .sha384:
      "SHA384"

    case .sha512:
      "SHA512"
    }
  }

  /// Parses the protocol's digest-name spelling; the SCS surface
  /// accepts SHA-1, SHA-256, SHA-384 and SHA-512 (v1.3 §2.5.2).
  public static func hash(named name: String) -> SigningHash? {
    switch name {
    case "SHA1":
      .sha1

    case "SHA256":
      .sha256

    case "SHA384":
      .sha384

    case "SHA512":
      .sha512

    default:
      nil
    }
  }

  /// The composed `signatureAlgorithm` response value for this key
  /// under `hash`.
  public func scsName(hash: SigningHash) -> String {
    let key =
      switch self {
      case .ecdsa:
        "ECDSA"

      case .rsa:
        "RSA"
      }
    return Self.scsName(hash: hash) + "with" + key
  }
}
