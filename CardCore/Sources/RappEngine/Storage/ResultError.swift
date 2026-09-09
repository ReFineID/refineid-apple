// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the specification registers them,
// so the source reads line for line against the document.
// swiftlint:disable sorted_enum_cases

import Foundation

/// Stable failure name accompanying a non-successful result.
internal enum ResultError: String, Equatable {
  case userDenied = "user_denied"
  case requestExpired = "request_expired"
  case cancelled = "cancelled"
  case requestInvalidOrUnsupported = "request_invalid_or_unsupported"
  case retryPolicyRefused = "retry_policy_refused"
  case credentialRejected = "credential_rejected"
  case cardRemovedBeforeTransmit = "card_removed_before_transmit"
  case cardCompletionAmbiguous = "card_completion_ambiguous"
}

// swiftlint:enable sorted_enum_cases
