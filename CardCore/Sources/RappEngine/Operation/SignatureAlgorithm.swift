// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One exact signature operation.
///
/// A digest family alone is insufficient: PKCS#1, PSS, and ECDSA are separate
/// card commands and are never interchangeable.
internal enum SignatureAlgorithm: String, CaseIterable, Equatable, Sendable {
  case ecdsaSha224 = "ecdsa_sha224"
  case ecdsaSha256 = "ecdsa_sha256"
  case ecdsaSha384 = "ecdsa_sha384"
  case ecdsaSha512 = "ecdsa_sha512"
  case rsaPkcs1Sha256 = "rsa_pkcs1_sha256"
  case rsaPkcs1Sha384 = "rsa_pkcs1_sha384"
  case rsaPkcs1Sha512 = "rsa_pkcs1_sha512"
  case rsaPssSha256 = "rsa_pss_sha256"

  /// Digest size this algorithm consumes.
  internal var digestLength: Int {
    switch self {
    case .ecdsaSha224:
      DigestLength.sha224

    case .ecdsaSha256, .rsaPkcs1Sha256, .rsaPssSha256:
      DigestLength.sha256

    case .ecdsaSha384, .rsaPkcs1Sha384:
      DigestLength.sha384

    case .ecdsaSha512, .rsaPkcs1Sha512:
      DigestLength.sha512
    }
  }

  /// Whether this is an elliptic-curve scheme rather than an RSA scheme.
  internal var isElliptic: Bool {
    switch self {
    case .ecdsaSha224, .ecdsaSha256, .ecdsaSha384, .ecdsaSha512:
      true

    case .rsaPkcs1Sha256, .rsaPkcs1Sha384, .rsaPkcs1Sha512, .rsaPssSha256:
      false
    }
  }

  /// A scheme runs only on a key of its own family.
  internal func supports(_ profile: CardKeyProfile) -> Bool {
    isElliptic == profile.isElliptic
  }
}
