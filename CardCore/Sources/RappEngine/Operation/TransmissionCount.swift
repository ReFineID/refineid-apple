// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Transmission counts a durable record may hold.
///
/// A credential command is transmitted at most once, so the count is only
/// ever untransmitted or the single transmission.
internal enum TransmissionCount {
  internal static let untransmitted: UInt8 = 0
  internal static let single: UInt8 = 1
}
