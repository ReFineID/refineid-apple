// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation

  extension RappOperationDriver.SignatureAlgorithm {
    /// The signing algorithm this RAPP algorithm names.
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

    /// Maps a signing algorithm onto its RAPP counterpart, or nil for a
    /// hash-scheme combination RAPP does not carry.
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
#endif
