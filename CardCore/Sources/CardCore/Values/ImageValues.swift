// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Byte values that identify an image encoding.
internal enum ImageValues {
  /// JP2 signature-box length.
  private static let jpeg2000BoxLength: UInt8 = 0x0C

  /// Carriage return in the fixed JP2 signature.
  private static let carriageReturn: UInt8 = 0x0D

  /// Line feed in the fixed JP2 signature.
  private static let lineFeed: UInt8 = 0x0A

  /// The non-ASCII check byte in the fixed JP2 signature.
  private static let jpeg2000Check: UInt8 = 0x87

  /// A zero byte used by the JP2 box length.
  private static let zero: UInt8 = 0

  /// Every JPEG marker opens with this byte (ITU-T T.81 B.1.1.3).
  internal static let markerIntroducer: UInt8 = 0xFF

  /// The start-of-image marker's own byte.
  internal static let startOfImage: UInt8 = 0xD8

  /// ISO/IEC 15444-1 JP2 signature box.
  internal static let jpeg2000Signature =
    [zero, zero, zero, jpeg2000BoxLength]
    + Array("jP  ".utf8)
    + [carriageReturn, lineFeed, jpeg2000Check, lineFeed]
}
