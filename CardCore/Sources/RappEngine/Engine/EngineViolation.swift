// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// An authenticated protocol violation seen by either engine.
///
/// Every case is attributable to the authenticated peer, so each one ends the
/// pairing under the failure policy.
internal enum EngineViolation: Equatable {
  case activeOperationIdentifierReused
  case illegalMessageForActiveOperation
  case illegalOperationTransition
  case invalidOperationMessage
  case invalidOperationRequest
  case profileNotGranted
  case referenceMismatch
  case unexpectedPreparedForSafeRead
}
