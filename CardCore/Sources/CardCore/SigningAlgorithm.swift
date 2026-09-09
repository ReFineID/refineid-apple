// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A FINEID signing algorithm, as the MSE:SET algorithm-reference byte.
public struct SigningAlgorithm: Equatable, Sendable {
  /// Number of bits in one nibble, for composing the reference byte.
  private static let nibbleWidth: UInt8 = 4

  /// The hash function.
  public let hash: SigningHash

  /// The signature scheme.
  public let scheme: SigningScheme

  /// The algorithm-reference byte: hash high nibble, scheme low nibble.
  internal var reference: UInt8 {
    hash.highNibble << Self.nibbleWidth | scheme.lowNibble
  }

  /// Composes an algorithm from its hash and scheme.
  public init(hash: SigningHash, scheme: SigningScheme) {
    self.hash = hash
    self.scheme = scheme
  }
}
