// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The measured policy values governing liveness probing.
///
/// The specification leaves these to measurement, so they are supplied rather
/// than fixed by the engine, and they are read on a monotonic clock.
public struct RappLivenessConfiguration: Equatable, Sendable {
  /// How long to wait between probes before backing off.
  public var baseIntervalMs: UInt64
  /// How long a probe may go unanswered before it counts as missed.
  public var responseTimeoutMs: UInt64
  /// The ceiling the backoff may reach.
  public var maximumIntervalMs: UInt64
  /// The most jitter that may be added to a scheduled probe.
  public var maximumJitterMs: UInt64
  /// How many missed probes close the session.
  public var maximumMisses: UInt8

  /// Supplies the measured values governing probing.
  public init(
    baseIntervalMs: UInt64,
    responseTimeoutMs: UInt64,
    maximumIntervalMs: UInt64,
    maximumJitterMs: UInt64,
    maximumMisses: UInt8
  ) {
    self.baseIntervalMs = baseIntervalMs
    self.responseTimeoutMs = responseTimeoutMs
    self.maximumIntervalMs = maximumIntervalMs
    self.maximumJitterMs = maximumJitterMs
    self.maximumMisses = maximumMisses
  }
}
