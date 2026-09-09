// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The exact MSE:SET shape already resolved from CryptoTokenKit's algorithm
/// chain.
///
/// Only public signature parameters cross the relay.
public enum PersistentRelaySigningAlgorithm: String, Codable, Sendable {
  case ecdsaSHA224 = "ecdsaSHA224"
  case ecdsaSHA256 = "ecdsaSHA256"
  case ecdsaSHA384 = "ecdsaSHA384"
  case ecdsaSHA512 = "ecdsaSHA512"
  case rsaPkcs1SHA256 = "rsaPkcs1SHA256"
  case rsaPkcs1SHA384 = "rsaPkcs1SHA384"
  case rsaPkcs1SHA512 = "rsaPkcs1SHA512"
  case rsaPssSHA256 = "rsaPssSHA256"

  /// The domain algorithm this wire value names.
  public var signingAlgorithm: SigningAlgorithm {
    switch self {
    case .ecdsaSHA224:
      SigningAlgorithm(hash: .sha224, scheme: .ecdsa)

    case .ecdsaSHA256:
      SigningAlgorithm(hash: .sha256, scheme: .ecdsa)

    case .ecdsaSHA384:
      SigningAlgorithm(hash: .sha384, scheme: .ecdsa)

    case .ecdsaSHA512:
      SigningAlgorithm(hash: .sha512, scheme: .ecdsa)

    case .rsaPkcs1SHA256:
      SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1)

    case .rsaPkcs1SHA384:
      SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1)

    case .rsaPkcs1SHA512:
      SigningAlgorithm(hash: .sha512, scheme: .rsaPkcs1)

    case .rsaPssSHA256:
      SigningAlgorithm(hash: .sha256, scheme: .rsaPss)
    }
  }

  /// Wraps a resolved signing algorithm, or nil for one the relay
  /// does not carry.
  public init?(_ algorithm: SigningAlgorithm) {
    switch (algorithm.scheme, algorithm.hash) {
    case (.ecdsa, .sha224):
      self = .ecdsaSHA224

    case (.ecdsa, .sha256):
      self = .ecdsaSHA256

    case (.ecdsa, .sha384):
      self = .ecdsaSHA384

    case (.ecdsa, .sha512):
      self = .ecdsaSHA512

    case (.rsaPkcs1, .sha256):
      self = .rsaPkcs1SHA256

    case (.rsaPkcs1, .sha384):
      self = .rsaPkcs1SHA384

    case (.rsaPkcs1, .sha512):
      self = .rsaPkcs1SHA512

    case (.rsaPss, .sha256):
      self = .rsaPssSHA256

    default:
      return nil
    }
  }
}
