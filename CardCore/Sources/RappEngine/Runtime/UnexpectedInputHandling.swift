// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists them, so
// the source reads line for line against the document.
// swiftlint:disable sorted_enum_cases

/// One step of an unexpected-input class's handling.
internal enum UnexpectedInputHandling: String, CaseIterable, Sendable {
  case discardInput = "discard_input"
  case closeCandidate = "close_candidate"
  case raiseSessionIntegrityFailed = "raise_session_integrity_failed"
  case sendErrorUnknownOperationIfUseful = "send_error_unknown_operation_if_useful"
  case raiseAuthenticatedProtocolViolation = "raise_authenticated_protocol_violation"
  case raiseLocalSecurityShutdown = "raise_local_security_shutdown"
  case discardWithoutResponse = "discard_without_response"
}

// swiftlint:enable sorted_enum_cases
