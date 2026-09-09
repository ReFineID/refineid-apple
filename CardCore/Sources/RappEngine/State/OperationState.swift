// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists them, so the
// tables read line for line against the document. Alphabetising them would
// break the correspondence the bidirectional conformance test protects.
// swiftlint:disable sorted_enum_cases

/// Operation component state.
///
/// An operation instance exists per operation identifier. Terminal states are
/// permanent journal records that accept no further transitions.
internal enum OperationState: String, CaseIterable, Sendable {
  case idle = "none"
  case requested = "requested"
  /// Proxy only.
  case awaitingConsent = "awaiting_consent"
  case prepared = "prepared"
  case committed = "committed"
  /// Proxy only.
  case executing = "executing"
  /// Proxy only.
  case resultPending = "result_pending"
  case completed = "completed"
  case denied = "denied"
  case cancelled = "cancelled"
  case rejected = "rejected"
  case credentialRejected = "credential_rejected"
  case ambiguous = "ambiguous"
  case deliveryUncertain = "delivery_uncertain"

  /// Whether this state is a permanent journal record.
  internal var isTerminal: Bool {
    switch self {
    case .completed, .denied, .cancelled, .rejected, .credentialRejected,
      .ambiguous, .deliveryUncertain:
      true

    case .idle, .requested, .awaitingConsent, .prepared, .committed, .executing,
      .resultPending:
      false
    }
  }

  /// Whether the instance occupies the single active-operation slot.
  internal var isActive: Bool {
    self != .idle && !isTerminal
  }
}

// swiftlint:enable sorted_enum_cases
