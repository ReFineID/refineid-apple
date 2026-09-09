// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists them, so the
// tables read line for line against the document. Alphabetising them would
// break the correspondence the bidirectional conformance test protects.
// swiftlint:disable sorted_enum_cases

/// Session component event.
internal enum SessionEvent: String, CaseIterable, Sendable {
  case connect = "connect"
  case transportAccepted = "transport_accepted"
  case transportConnected = "transport_connected"
  case transportFailed = "transport_failed"
  case userDisconnect = "user_disconnect"
  case handshakeComplete = "handshake_complete"
  case secondSessionDetected = "second_session_detected"
  case readyVerified = "ready_verified"
  /// Handshake failure or pre-authentication garbage; policy class 1.
  case candidateFailure = "candidate_failure"
  case busyReceived = "busy_received"
  case peerCloseReceived = "peer_close_received"
  /// Policy class 4.
  case authenticatedProtocolViolation = "authenticated_protocol_violation"
  case livenessMissed = "liveness_missed"
  case livenessRestored = "liveness_restored"
  case livenessDeadlineExpired = "liveness_deadline_expired"
  /// Produced by the operation action that requests a session close.
  case localCloseRequested = "local_close_requested"
  /// Produced by the operation action for a rejected credential.
  case credentialRejected = "credential_rejected"
  case cardCompletionAmbiguous = "card_completion_ambiguous"
  /// Policy class 2; no pairing effect.
  case sessionIntegrityFailed = "session_integrity_failed"
  /// Produced by pairing actions and rule X-01.
  case closeRequestedByPairing = "close_requested_by_pairing"
  /// Policy class 5.
  case localSecurityShutdown = "local_security_shutdown"
  case closeCompleteOrDeadline = "close_complete_or_deadline"
}

// swiftlint:enable sorted_enum_cases
