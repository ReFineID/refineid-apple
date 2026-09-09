// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A READ BINARY direct offset: 15 bits, encoded in P1-P2 with the top
/// bit of P1 clear.
public struct ReadOffset: Equatable, Sendable {
  /// The highest encodable offset.
  public static let maximum: UInt16 = Iso7816Values.readBinaryOffsetMaximum

  /// Bytes addressable from offset zero through the highest offset.
  public static let maximumAddressableLength = Int(Self.maximum) + 1

  /// The validated offset value.
  public let value: UInt16

  /// P1 byte: the high seven bits.
  internal var p1Byte: UInt8 {
    UInt8(value >> Iso7816Values.byteShift)
  }

  /// P2 byte: the low byte.
  internal var p2Byte: UInt8 {
    UInt8(value & Iso7816Values.lowByteMask)
  }

  /// Refuses offsets above the 15-bit maximum.
  public init?(value: UInt16) {
    guard value <= Self.maximum else { return nil }
    self.value = value
  }
}
