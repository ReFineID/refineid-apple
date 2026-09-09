// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists them, so the
// tables read line for line against the document. Alphabetising them would
// break the correspondence the bidirectional conformance test protects.
// swiftlint:disable sorted_enum_cases

/// Operation component event.
///
/// Two names carry an `operation_` prefix in the model that the Swift case
/// drops for readability: `operation_request_sent` and
/// `operation_request_received`. The raw values remain the model's.
internal enum OperationEvent: String, CaseIterable, Sendable {
  case requestSent = "operation_request_sent"
  case requestReceived = "operation_request_received"
  case requestValid = "request_valid"
  case requestInvalidOrUnsupported = "request_invalid_or_unsupported"
  case cancelReceived = "cancel_received"
  case requestExpired = "request_expired"
  case userDenied = "user_denied"
  case retryPolicyRefused = "retry_policy_refused"
  case invalidCanOrPin1OrPin2 = "invalid_can_or_pin1_or_pin2"
  case safeReadsComplete = "safe_reads_complete"
  case userApprovedAndProxyReady = "user_approved_and_proxy_ready"
  case validCommit = "valid_commit"
  case beginCardCommand = "begin_card_command"
  case crashRecoveredWithoutTerminalResult = "crash_recovered_without_terminal_result"
  case cardSuccess = "card_success"
  case cardPolicyRejection = "card_policy_rejection"
  case cardRemovedBeforeTransmit = "card_removed_before_transmit"
  case cardRemovedOrTransportUncertain = "card_removed_or_transport_uncertain"
  /// Produced by rule X-03 or X-04.
  case sessionClosedPostCommit = "session_closed_post_commit"
  case validResultAck = "valid_result_ack"
  /// Produced by rule X-05.
  case sessionClosedBeforeAck = "session_closed_before_ack"
  case preparedReceived = "prepared_received"
  case cancelSentOrRequestExpired = "cancel_sent_or_request_expired"
  case commitSent = "commit_sent"
  case resultCompletedReceived = "result_completed_received"
  case resultDeniedReceived = "result_denied_received"
  case resultCancelledReceived = "result_cancelled_received"
  case resultRejectedReceived = "result_rejected_received"
  case resultCredentialRejectedReceived = "result_credential_rejected_received"
  case resultAmbiguousReceived = "result_ambiguous_received"
  /// Produced by rule X-02.
  case sessionClosedPreCommit = "session_closed_pre_commit"
}

// swiftlint:enable sorted_enum_cases
