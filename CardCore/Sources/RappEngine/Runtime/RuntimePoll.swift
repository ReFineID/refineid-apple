// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What advancing the liveness policy produced.
internal enum RuntimePoll: Equatable {
  case alreadyClosed
  /// A probe went unanswered; new operations are blocked while recovering.
  case checking(nextProbeAtMilliseconds: UInt64, outcome: RappSecurityOutcome)
  case noAction
  /// A probe to send.
  case send(BinaryFrame)
  /// The hard deadline closed the session.
  case sessionClosed(RappSecurityOutcome)
}
