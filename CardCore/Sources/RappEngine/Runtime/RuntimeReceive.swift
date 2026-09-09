// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What processing one received frame produced.
///
/// Every case carries data. The runtime decides nothing on the caller's
/// behalf and performs no effect, so the ordered actions a security event
/// produces stay the state tables' description rather than becoming a second
/// implementation here.
internal enum RuntimeReceive: Equatable {
  /// Input with no effect, and the class that says so.
  case discarded(UnexpectedInputClass)
  /// An exact echo restored liveness.
  case livenessRestored(RappSecurityOutcome)
  /// An authenticated message for the caller.
  case message(Envelope)
  /// An authenticated violation ended the pairing.
  case pairingEnded(RappSecurityOutcome)
  /// A frame the runtime produced centrally, ready to send.
  case send(BinaryFrame)
  /// The session closed; the pairing is untouched.
  case sessionClosed(RappSecurityOutcome)
}
