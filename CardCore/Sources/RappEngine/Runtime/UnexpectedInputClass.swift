// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists the policy
// classes, so the source reads line for line against the document.
// swiftlint:disable sorted_enum_cases

/// How an endpoint answers input that no transition governs.
///
/// Every input the tables do not govern belongs to exactly one of these
/// classes, and the class decides the answer. Without them an unexpected
/// message would have no defined handling, and the tempting default -- treat
/// anything unrecognised as an attack -- would let ordinary races end
/// pairings.
internal enum UnexpectedInputClass: String, CaseIterable, Sendable {
  /// Malformed or unauthenticated input during offers, connection, or a
  /// handshake.
  case preAuthenticationInvalidInput = "pre_authentication_invalid_input"
  /// A frame on an authenticated session that fails decryption or framing.
  case establishedChannelIntegrityFailure = "established_channel_integrity_failure"
  /// A decrypted message about an unknown or finished operation, a duplicate
  /// commit matching the committed record, or a pong matching no ping.
  case staleReferenceRace = "stale_reference_race"
  /// A decrypted message with a schema, sequence, session, or echo violation,
  /// or one with no legal transition and no stale-reference reading.
  case authenticatedProtocolViolation = "authenticated_protocol_violation"
  /// A local invariant failed inside this implementation.
  case localInternalFault = "local_internal_fault"
  /// Any frame for a closed or unknown session.
  case trafficAfterClosed = "traffic_after_closed"

  /// The ordered handling the model names for this class.
  internal var handling: [UnexpectedInputHandling] {
    switch self {
    case .preAuthenticationInvalidInput:
      [.discardInput, .closeCandidate]

    case .establishedChannelIntegrityFailure:
      [.raiseSessionIntegrityFailed]

    case .staleReferenceRace:
      [.discardInput, .sendErrorUnknownOperationIfUseful]

    case .authenticatedProtocolViolation:
      [.raiseAuthenticatedProtocolViolation]

    case .localInternalFault:
      [.raiseLocalSecurityShutdown]

    case .trafficAfterClosed:
      [.discardWithoutResponse]
    }
  }

  /// Whether this class may end a pairing.
  ///
  /// Only the authenticated class may, which is invariant INV-18 read from
  /// the other direction.
  internal var mayEndPairing: Bool {
    self == .authenticatedProtocolViolation
  }
}

// swiftlint:enable sorted_enum_cases
