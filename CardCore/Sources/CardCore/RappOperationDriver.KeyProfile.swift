// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation

  extension RappOperationDriver.KeyProfile {
    /// The card key profile this RAPP profile names.
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

    /// Maps a card key profile onto its RAPP counterpart.
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
#endif
