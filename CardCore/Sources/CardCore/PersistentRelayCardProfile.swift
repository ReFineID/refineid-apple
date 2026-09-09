// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The card-key facts needed to resolve a signature without rereading the
/// certificate during the short NFC signing field.
public enum PersistentRelayCardProfile: String, Codable, Sendable {
  case ecdsaP256 = "ecdsaP256"
  case ecdsaP384 = "ecdsaP384"
  case rsa2048 = "rsa2048"
  case rsa3072 = "rsa3072"

  /// The domain profile this wire value names.
  public var cardKeyProfile: CardKeyProfile {
    switch self {
    case .ecdsaP256:
      .ecdsaP256

    case .ecdsaP384:
      .ecdsaP384

    case .rsa2048:
      .rsa2048

    case .rsa3072:
      .rsa3072
    }
  }

  /// Wraps a resolved card key profile for the wire.
  public init(_ profile: CardKeyProfile) {
    self =
      switch profile {
      case .ecdsaP256:
        .ecdsaP256

      case .ecdsaP384:
        .ecdsaP384

      case .rsa2048:
        .rsa2048

      case .rsa3072:
        .rsa3072
      }
  }
}
