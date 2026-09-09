// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A refused engine step.
internal enum EngineError: Error, Equatable {
  /// Authenticated peer traffic broke the protocol.
  case authenticatedProtocolViolation(EngineViolation)
  /// The local caller reused a live operation identifier.
  case duplicateLocalOperationIdentifier
  /// The local caller asked for a transition the machine does not define.
  case invalidLocalTransition
  /// A locally produced value failed its own validation.
  case invalidLocalValue
  /// Durable state contradicts a machine invariant.
  case localInvariantFailure
  /// The peer's request expired before it could be admitted.
  case peerRequestExpired
  /// Durable storage failed, so no credential command may be released.
  case persistence
  /// The local caller named an operation this engine does not hold.
  case unknownLocalOperation
}
