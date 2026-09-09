// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Public-key profile the requester expects, checked again by the authorizer.
internal enum CardKeyProfile: String, CaseIterable, Equatable, Sendable {
  case ecdsaP256 = "ecdsa_p256"
  case ecdsaP384 = "ecdsa_p384"
  case rsa2048 = "rsa_2048"
  case rsa3072 = "rsa_3072"

  /// Whether this is an elliptic-curve key rather than an RSA key.
  internal var isElliptic: Bool {
    switch self {
    case .ecdsaP256, .ecdsaP384:
      true

    case .rsa2048, .rsa3072:
      false
    }
  }
}
