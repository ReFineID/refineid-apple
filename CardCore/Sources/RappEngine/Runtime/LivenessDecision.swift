// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are ordered as a probe escalates, so the source reads in the
// order the decisions can occur.
// swiftlint:disable sorted_enum_cases

import Foundation

/// What a timer tick asks the session to do.
internal enum LivenessDecision: Equatable {
  /// Nothing is due.
  case noAction
  /// Send a ping carrying this challenge.
  case sendPing(PingChallenge)
  /// A probe went unanswered; the next one is due at this monotonic time.
  case probeMissed(nextProbeAtMilliseconds: UInt64)
  /// Repeated loss closes this session and nothing further.
  case closeSession
  /// The tracker was already closed.
  case alreadyClosed
}

// swiftlint:enable sorted_enum_cases
