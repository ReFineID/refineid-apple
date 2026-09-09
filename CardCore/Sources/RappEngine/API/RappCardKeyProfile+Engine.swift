// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Translations between the public vocabulary and the engine's own.
///
/// The public names are the ones callers already wrote against, so they are
/// kept even where the engine spells a value differently.
extension RappCardKeyProfile {
  internal var engineProfile: CardKeyProfile {
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

  internal init(_ profile: CardKeyProfile) {
    switch profile {
    case .ecdsaP256:
      self = .ecdsaP256

    case .ecdsaP384:
      self = .ecdsaP384

    case .rsa2048:
      self = .rsa2048

    case .rsa3072:
      self = .rsa3072
    }
  }
}
