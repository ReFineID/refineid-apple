// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// How many times a credential may still be used before the card
/// stops honouring it at all (FINEID S1 v4.2 §3.15.3 Table 19).
///
/// This is not the retry counter. A retry counter falls when the wrong
/// value is presented and is restored by an unblock; an allowance
/// falls when the RIGHT value is presented, and nothing restores it.
/// A PUK with a limited unblocking allowance is spent by being used,
/// which is what makes the difference between a card whose PUK works
/// once and one whose PUK keeps working.
public enum CredentialAllowance: Equatable, Sendable {
  /// This many uses remain.
  case remaining(UInt8)

  /// The card puts no limit on this count.
  case unlimited

  /// Reads a usage-allowance byte.
  internal static func usage(byte: UInt8) -> Self {
    byte == FineidValues.usageUnlimited ? .unlimited : .remaining(byte)
  }

  /// Reads an unblocking-allowance byte, whose no-limit marker differs
  /// from the usage one.
  internal static func unblocking(byte: UInt8) -> Self {
    byte == FineidValues.unblockingUnlimited ? .unlimited : .remaining(byte)
  }
}
