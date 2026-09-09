// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The dedicated home for the AES-CMAC byte constants.
///
/// Every constant is named and documented here exactly once; no other
/// production or test file may carry a raw hex literal
/// (`.swiftlint.yml` `unexplained_hex`). Section references are to RFC 4493,
/// whose construction NIST SP 800-38B publishes as the CMAC mode.
internal enum AesCmacValues {
  /// The only non-zero byte of the constant Rb for a 128-bit block
  /// (section 2.3).
  ///
  /// Rb is fifteen zero bytes followed by this one: the low half of the
  /// polynomial that generates the field the subkey derivation shifts in.
  internal static let rbLowByte: UInt8 = 0x87

  /// The marker that starts the padding of a short final block
  /// (section 2.4): a single one bit, then zero bits to the block boundary.
  ///
  /// This is the same padding ISO/IEC 7816-4 prescribes for secure
  /// messaging, which is why the card protocol and the MAC agree on it.
  internal static let paddingMarker: UInt8 = 0x80

  /// Mask selecting the most significant bit of a byte.
  ///
  /// The subkey derivation (section 2.3) tests this bit before deciding
  /// whether to add Rb after a left shift.
  internal static let highBitMask: UInt8 = 0x80
}
