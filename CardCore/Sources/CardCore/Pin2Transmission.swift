// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A PIN2 in transit to the card, usable for one command only.
///
/// The only way to obtain this value is consuming a `Pin2`; the only code
/// that may read it is the module's own transport boundary when it builds
/// the single credential-bearing command. It is noncopyable for the same
/// reason its source is: transmit-once is a compile-time property.
public struct Pin2Transmission: ~Copyable {
  /// The digits, still owned by the zeroizing store.
  internal let store: ZeroizingDigitStore
}
