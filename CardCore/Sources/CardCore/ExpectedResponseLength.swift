// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The expected response length (Le) of a short APDU: 1-256 bytes,
/// where 256 encodes as the byte `00` on the wire.
public struct ExpectedResponseLength: Equatable, Sendable {
  /// The largest short-form response.
  public static let maximum: Int = 256

  /// The validated byte count.
  public let count: Int

  /// The wire encoding of Le.
  internal var encodedByte: UInt8 {
    if count == Self.maximum {
      return Iso7816Values.expectedLengthMaximumEncoding
    }
    return UInt8(count)
  }

  /// Refuses zero and anything beyond the short-form maximum.
  public init?(count: Int) {
    guard count >= 1, count <= Self.maximum else { return nil }
    self.count = count
  }
}
