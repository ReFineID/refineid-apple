// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Shared validation for entered credential digits.
///
/// One implementation of the length-and-character rule, so PIN1, PIN2,
/// and PUK cannot drift apart in what they accept.
internal enum CredentialDigits {
  /// ASCII "0".
  private static let asciiDigitMinimum: UInt8 = 48

  /// ASCII "9".
  private static let asciiDigitMaximum: UInt8 = 57

  /// Validates length and character set, returning a store owning the
  /// digits, or nil for anything that is not `minimumCount` to
  /// `maximumCount` ASCII digits.
  internal static func validated(
    _ digits: String,
    minimumCount: Int,
    maximumCount: Int
  ) -> ZeroizingDigitStore? {
    let bytes = Array(digits.utf8)
    guard
      bytes.count >= minimumCount,
      bytes.count <= maximumCount,
      bytes.allSatisfy({ byte in
        byte >= asciiDigitMinimum && byte <= asciiDigitMaximum
      })
    else {
      return nil
    }
    return ZeroizingDigitStore(bytes: bytes)
  }
}
