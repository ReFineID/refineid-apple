// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Structure of an answer to reset, as ISO 7816-3 section 8 defines it.
///
/// Named here rather than written into the parser, so the parser reads
/// as the standard's own description of the format.
internal enum AnswerToResetValues {
  /// Where `T0` sits: after `TS`, the convention byte.
  internal static let formatByteIndex: Int = 1

  /// How many historical bytes there are: the low nibble of `T0`.
  internal static let historicalCountMask: UInt8 = 0x0F

  /// Which bytes follow: the high nibble of `T0` and of each `TD`.
  internal static let interfacePresenceShift: UInt8 = 4

  /// Bits 1 to 3 of that nibble announce `TA`, `TB` and `TC`, in order.
  ///
  /// A set rather than three separately named constants, because the
  /// parser walks them as one.
  internal static let interfaceByteBits: [UInt8] = [
    0x01, 0x02, 0x04,
  ]

  /// Bit 4 of it announces a further `TD`, and a further group after.
  internal static let protocolByteBit: UInt8 = 0x08

  /// The answer a PC/SC reader synthesizes for a card reached over its
  /// contactless interface (PC/SC part 3, section 3.1.3.2.3).
  ///
  /// A contactless card has no answer to reset of its own, so the
  /// reader builds one: `TS` direct convention, `T0` announcing only a
  /// `TD1` beside the historical count, and the fixed `TD1 TD2` pair
  /// `80 01`. The historical count varies with the card; everything
  /// else in the prefix does not, which is what makes the prefix
  /// answer "which interface is this card on" without any card I/O.
  internal static let synthesizedContactlessPrefix: [UInt8] = [
    0x3B, 0x80, 0x80, 0x01,
  ]

  /// The historical-count nibble, masked away when comparing the
  /// prefix above.
  internal static let synthesizedContactlessMasks: [UInt8] = [
    0xFF, 0xF0, 0xFF, 0xFF,
  ]
}
