// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Translations between the public vocabulary and the engine's own.
///
/// The public names are the ones callers already wrote against, so they are
/// kept even where the engine spells a value differently.
extension RappSignatureAlgorithm {
  internal var engineAlgorithm: SignatureAlgorithm {
    switch self {
    case .ecdsaSha224:
      .ecdsaSha224

    case .ecdsaSha256:
      .ecdsaSha256

    case .ecdsaSha384:
      .ecdsaSha384

    case .ecdsaSha512:
      .ecdsaSha512

    case .rsaPkcs1Sha256:
      .rsaPkcs1Sha256

    case .rsaPkcs1Sha384:
      .rsaPkcs1Sha384

    case .rsaPkcs1Sha512:
      .rsaPkcs1Sha512

    case .rsaPssSha256:
      .rsaPssSha256
    }
  }

  internal init(_ algorithm: SignatureAlgorithm) {
    switch algorithm {
    case .ecdsaSha224:
      self = .ecdsaSha224

    case .ecdsaSha256:
      self = .ecdsaSha256

    case .ecdsaSha384:
      self = .ecdsaSha384

    case .ecdsaSha512:
      self = .ecdsaSha512

    case .rsaPkcs1Sha256:
      self = .rsaPkcs1Sha256

    case .rsaPkcs1Sha384:
      self = .rsaPkcs1Sha384

    case .rsaPkcs1Sha512:
      self = .rsaPkcs1Sha512

    case .rsaPssSha256:
      self = .rsaPssSha256
    }
  }
}
