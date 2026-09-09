// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The hash function of a FINEID signing algorithm reference.
///
/// Carried as the high nibble of the MSE:SET algorithm-reference byte
/// (FINEID S1 v4.2 §3.6.3 Table 6).
public enum SigningHash: Equatable, Sendable {
  /// SHA-1 (high nibble 1).
  case sha1

  /// SHA-224 (high nibble 3).
  case sha224

  /// SHA-256 (high nibble 4).
  case sha256

  /// SHA-384 (high nibble 5).
  case sha384

  /// SHA-512 (high nibble 6).
  case sha512

  /// SHA-1 digest width.
  private static let sha1ByteCount = 20

  /// SHA-224 digest width.
  private static let sha224ByteCount = 28

  /// SHA-256 digest width.
  private static let sha256ByteCount = 32

  /// SHA-384 digest width.
  private static let sha384ByteCount = 48

  /// SHA-512 digest width.
  private static let sha512ByteCount = 64

  /// Exact digest size this hash contributes to PSO:HASH.
  public var digestByteCount: Int {
    switch self {
    case .sha1:
      Self.sha1ByteCount

    case .sha224:
      Self.sha224ByteCount

    case .sha256:
      Self.sha256ByteCount

    case .sha384:
      Self.sha384ByteCount

    case .sha512:
      Self.sha512ByteCount
    }
  }

  /// The high nibble contributed to the algorithm-reference byte.
  internal var highNibble: UInt8 {
    switch self {
    case .sha1:
      FineidValues.hashNibbleSha1

    case .sha224:
      FineidValues.hashNibbleSha224

    case .sha256:
      FineidValues.hashNibbleSha256

    case .sha384:
      FineidValues.hashNibbleSha384

    case .sha512:
      FineidValues.hashNibbleSha512
    }
  }
}
