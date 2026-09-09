// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A security-relevant event an endpoint observed.
///
/// There is deliberately no strike counter. The first authenticated protocol
/// violation ends the pairing, while a failure that cannot be attributed to
/// the peer stays session-scoped, so an unauthenticated attacker on the
/// network cannot destroy a pairing by corrupting traffic.
internal enum SecurityIncident: Equatable, Sendable {
  /// A decrypted, authenticated message broke the grammar, sequence, role,
  /// profile, or granted set.
  case authenticatedProtocolViolation
  /// Connectivity was lost after the journal committed the card command, so
  /// the command must never be repeated and its result is unknown.
  case committedResultUnknown
  /// The card refused a credential during an operation.
  case credentialRejected(CredentialKind)
  /// A request or approval expired before the card command was committed.
  case operationExpired
  /// A frame could not be decrypted or authenticated for this session.
  case sessionIntegrityFailure
  /// The transport disconnected or became unavailable.
  case transportFailure
  /// The authorizer refused the request.
  case userRejected

  /// The response the specification requires on the first such incident.
  internal var disposition: IncidentDisposition {
    switch self {
    case .authenticatedProtocolViolation:
      IncidentDisposition(
        pairing: .endImmediately, session: .closeImmediately, operation: .fail,
        requiresNewUserIntent: true)

    case .sessionIntegrityFailure, .transportFailure:
      IncidentDisposition(
        pairing: .keep, session: .closeImmediately, operation: .resolveFromJournal,
        requiresNewUserIntent: true)

    case .credentialRejected:
      IncidentDisposition(
        pairing: .keep, session: .closeImmediately, operation: .reject,
        requiresNewUserIntent: true)

    case .userRejected, .operationExpired:
      IncidentDisposition(
        pairing: .keep, session: .keep, operation: .reject, requiresNewUserIntent: true)

    case .committedResultUnknown:
      IncidentDisposition(
        pairing: .keep, session: .closeImmediately, operation: .ambiguousNeverRetry,
        requiresNewUserIntent: true)
    }
  }
}
