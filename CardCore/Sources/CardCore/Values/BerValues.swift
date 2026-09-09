// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The encoding rules a travel document's files are written under.
internal enum BerValues {
  /// The byte that introduces a two-byte tag, rather than being one
  /// (ISO 8825-1, the high-tag-number form for this tag class).
  internal static let twoByteTagIntroducer: UInt8 = 0x5F

  /// Bytes in a two-byte tag.
  internal static let twoByteTagLength = 2

  /// Bytes in an ordinary tag.
  internal static let oneByteTagLength = 1

  /// Bytes in the octet that opens a length.
  internal static let lengthIntroducerLength = 1

  /// The bit set in a length octet when the length itself follows in
  /// further octets.
  internal static let longFormFlag: UInt8 = 0x80

  /// The remaining bits of that octet, which count those octets.
  internal static let longFormCountMask: UInt8 = 0x7F

  /// The most length octets accepted: four bound every file a travel
  /// document carries, and more would overflow the length into the
  /// sign bit.
  internal static let longFormMaximumOctets = 4
}
