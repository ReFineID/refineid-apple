// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One session's liveness timer.
///
/// The tracker owns no clock. Every decision is a pure function of an injected
/// monotonic timestamp, so a schedule is reproducible in a test and cannot
/// drift with wall-clock changes.
internal struct LivenessTracker {
  private enum Phase: Equatable {
    case waiting(nextProbeAtMilliseconds: UInt64, consecutiveMisses: UInt8)
    case awaitingPong(
      challenge: PingChallenge, deadlineMilliseconds: UInt64, consecutiveMisses: UInt8)
    case closed
  }

  /// The smallest interval a negative jitter may produce, so a schedule can
  /// never collapse to an immediate reprobe.
  private static let minimumJitteredInterval: UInt64 = 1

  /// Largest shift the backoff applies before it saturates.
  private static let maximumBackoffShift: UInt8 = 63

  private let configuration: LivenessConfiguration

  private var phase: Phase

  /// Whether the tracker still expects an echo for a probe it sent.
  internal var hasOutstandingChallenge: Bool {
    if case .awaitingPong = phase { return true }
    return false
  }

  internal init(configuration: LivenessConfiguration, nowMilliseconds: UInt64) throws {
    let validated = try configuration.validated()
    self.configuration = validated
    phase = .waiting(
      nextProbeAtMilliseconds: nowMilliseconds &+ validated.baseIntervalMilliseconds,
      consecutiveMisses: 0)
  }

  private static func jittered(
    interval: UInt64,
    maximumJitter: UInt64,
    jitter: Int64
  ) -> UInt64 {
    let magnitude = min(jitter.magnitude, maximumJitter)
    if jitter < 0 {
      return max(interval > magnitude ? interval - magnitude : 0, minimumJitteredInterval)
    }
    return interval &+ magnitude
  }

  /// Advances the timer.
  ///
  /// The challenge is consumed only when a probe is due.
  internal mutating func poll(
    nowMilliseconds: UInt64,
    nextChallenge: PingChallenge,
    jitterMilliseconds: Int64
  ) -> LivenessDecision {
    switch phase {
    case .waiting(let nextProbeAt, let misses) where nowMilliseconds >= nextProbeAt:
      phase = .awaitingPong(
        challenge: nextChallenge,
        deadlineMilliseconds: nowMilliseconds &+ configuration.responseTimeoutMilliseconds,
        consecutiveMisses: misses)
      return .sendPing(nextChallenge)

    case .awaitingPong(_, let deadline, let misses) where nowMilliseconds >= deadline:
      return missProbe(nowMilliseconds: nowMilliseconds, misses: misses, jitter: jitterMilliseconds)

    case .closed:
      return .alreadyClosed

    case .waiting, .awaitingPong:
      return .noAction
    }
  }

  /// Accepts only the exact challenge currently outstanding.
  internal mutating func receivePong(
    nowMilliseconds: UInt64,
    challenge: PingChallenge
  ) -> PongDisposition {
    guard case .awaitingPong(let expected, _, _) = phase, challenge == expected else {
      return .ignoredUnmatched
    }
    phase = .waiting(
      nextProbeAtMilliseconds: nowMilliseconds &+ configuration.baseIntervalMilliseconds,
      consecutiveMisses: 0)
    return .accepted
  }

  /// Closes this tracker permanently.
  internal mutating func close() {
    phase = .closed
  }

  private mutating func missProbe(
    nowMilliseconds: UInt64,
    misses: UInt8,
    jitter: Int64
  ) -> LivenessDecision {
    let attempted = misses == UInt8.max ? misses : misses + 1
    guard attempted < configuration.maximumMisses else {
      phase = .closed
      return .closeSession
    }
    let interval = Self.jittered(
      interval: backoffInterval(misses: attempted),
      maximumJitter: configuration.maximumJitterMilliseconds,
      jitter: jitter)
    let nextProbeAt = nowMilliseconds &+ interval
    phase = .waiting(nextProbeAtMilliseconds: nextProbeAt, consecutiveMisses: attempted)
    return .probeMissed(nextProbeAtMilliseconds: nextProbeAt)
  }

  /// Doubles the base interval once per miss, bounded by the policy ceiling.
  private func backoffInterval(misses: UInt8) -> UInt64 {
    let shift = min(misses, Self.maximumBackoffShift)
    let multiplier = UInt64(1) << UInt64(shift)
    let scaled = configuration.baseIntervalMilliseconds.multipliedReportingOverflow(by: multiplier)
    let interval = scaled.overflow ? UInt64.max : scaled.partialValue
    return min(interval, configuration.maximumIntervalMilliseconds)
  }
}
