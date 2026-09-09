// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The timing policy for liveness, expressed against a monotonic clock.
///
/// Every value is injected. The specification is explicit that heartbeat
/// intervals, backoff limits, and deadlines are measurement-determined policy
/// rather than interface delays, so none of them is fixed here.
internal struct LivenessConfiguration: Equatable {
  /// Idle time before the first probe.
  internal let baseIntervalMilliseconds: UInt64
  /// Time a pong is allowed to take.
  internal let responseTimeoutMilliseconds: UInt64
  /// Ceiling the exponential backoff cannot exceed.
  internal let maximumIntervalMilliseconds: UInt64
  /// Largest absolute jitter the caller may apply after a missed probe.
  internal let maximumJitterMilliseconds: UInt64
  /// Consecutive missed probes that close the session.
  internal let maximumMisses: UInt8

  /// Rejects a policy that cannot describe a probe schedule.
  internal func validated() throws -> Self {
    guard baseIntervalMilliseconds > 0,
      responseTimeoutMilliseconds > 0,
      maximumIntervalMilliseconds >= baseIntervalMilliseconds,
      maximumJitterMilliseconds <= baseIntervalMilliseconds,
      maximumMisses > 0
    else { throw LivenessError.invalidConfiguration }
    return self
  }
}
