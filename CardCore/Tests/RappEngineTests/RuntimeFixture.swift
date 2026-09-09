// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Fixed values the runtime harness drives its policy and channels with.
internal enum RuntimeFixture {
  /// Distinct fills, so a channel mix-up is visible rather than silent.
  internal static let firstKeyFill: UInt8 = 0xA1
  internal static let secondKeyFill: UInt8 = 0xB2
  internal static let sessionFill: UInt8 = 0x5E

  /// A schedule short enough to drive by hand, in milliseconds.
  internal static let baseInterval: UInt64 = 1_000
  internal static let responseTimeout: UInt64 = 500
  internal static let maximumInterval: UInt64 = 16_000
  internal static let maximumMisses: UInt8 = 3
}
