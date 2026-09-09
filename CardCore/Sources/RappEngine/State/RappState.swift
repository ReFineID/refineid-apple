// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// One endpoint's projection of the three component machines.
///
/// Security events span components, so they are applied here rather than to a
/// single machine. Each composite is expressed by resolving the component
/// rules, never by a second hand-written action list, so the tables stay the
/// only description of what an event does.
internal struct RappState: Sendable, Equatable {
  internal var role: EndpointRole
  internal var pairing: PairingState
  internal var session: SessionState
  internal var operation: OperationState
  /// A credential rejection requires a fresh explicit user action.
  internal var requiresUserIntent: Bool

  /// Rule X-08 and invariants INV-01, INV-02, and INV-04.
  internal var operationAdmissionPermitted: Bool {
    pairing == .pairedConnected && session == .healthy && operation == .idle
  }

  /// The operation event a session close delivers, per rules X-02 to X-05.
  ///
  /// Returns nil when no operation instance is affected.
  internal var operationEventForSessionClose: OperationEvent? {
    switch operation {
    case .requested, .awaitingConsent, .prepared:
      .sessionClosedPreCommit

    case .committed, .executing:
      .sessionClosedPostCommit

    case .resultPending:
      .sessionClosedBeforeAck

    case .idle, .completed, .denied, .cancelled, .rejected, .credentialRejected,
      .ambiguous, .deliveryUncertain:
      nil
    }
  }

  internal init(role: EndpointRole) {
    self.role = role
    self.pairing = .unpaired
    self.session = .absent
    self.operation = .idle
    self.requiresUserIntent = false
  }

  /// Applies the operation half of a session close and returns its actions.
  private mutating func closeActiveOperation() -> [RappAction] {
    guard let event = operationEventForSessionClose,
      case .fire(let transition) = OperationState.outcome(
        from: operation, on: event, role: role)
    else { return [] }
    operation = transition.state
    return transition.actions
  }

  /// Applies a session-machine event and returns its actions.
  private mutating func applySession(_ event: SessionEvent, guards: RappGuards) -> [RappAction] {
    guard
      case .fire(let transition) = SessionState.outcome(
        from: session, on: event, role: role, guards: guards)
    else { return [] }
    session = transition.state
    return transition.actions
  }

  /// Applies a pairing-machine event and returns its actions.
  private mutating func applyPairing(_ event: PairingEvent, guards: RappGuards) -> [RappAction] {
    guard
      case .fire(let transition) = PairingState.outcome(
        from: pairing, on: event, role: role, guards: guards)
    else { return [] }
    pairing = transition.state
    return transition.actions
  }

  /// A successfully decrypted message that has no legal transition and no
  /// stale-reference classification.
  ///
  /// The first attributable violation revokes a stored pairing. Before a
  /// pairing is stored the attempt aborts and nothing is recorded.
  internal mutating func authenticatedProtocolViolation() -> RappSecurityOutcome {
    var actions = closeActiveOperation()
    actions += applySession(.authenticatedProtocolViolation, guards: .allSatisfied)
    if pairing.holdsStoredPairing {
      actions += applyPairing(.authenticatedProtocolViolation, guards: .allSatisfied)
    } else {
      actions += applyPairing(.deniedAbortedOrTimedOut, guards: .allSatisfied)
    }
    return RappSecurityOutcome(actions: actions)
  }

  /// A frame on an authenticated session that fails decryption or framing.
  ///
  /// Invariant INV-18: the input is not attributable to the authenticated
  /// peer, so it closes the session and never revokes the pairing.
  internal mutating func sessionIntegrityFailed() -> RappSecurityOutcome {
    let pairingBefore = pairing
    var actions = closeActiveOperation()
    actions += applySession(.sessionIntegrityFailed, guards: .allSatisfied)
    precondition(pairing == pairingBefore, "unattributable input changed the pairing")
    return RappSecurityOutcome(actions: actions)
  }

  /// An unanswered authenticated liveness probe blocks new operations while
  /// preserving the pairing and the session keys.
  internal mutating func livenessMissed() -> RappSecurityOutcome {
    RappSecurityOutcome(actions: applySession(.livenessMissed, guards: .allSatisfied))
  }

  /// An exact authenticated echo restores operation admission.
  internal mutating func livenessRestored() -> RappSecurityOutcome {
    RappSecurityOutcome(actions: applySession(.livenessRestored, guards: .allSatisfied))
  }

  /// Invalid CAN, PIN 1, or PIN 2, applied across the components.
  ///
  /// Rule X-06: the session closes and both peers revoke the pair on the
  /// first incident. Invariant INV-17: no automatic reconnection follows.
  internal mutating func credentialRejected() -> RappSecurityOutcome {
    var actions: [RappAction] = []
    if case .fire(let transition) = OperationState.outcome(
      from: operation, on: .invalidCanOrPin1OrPin2, role: role)
    {
      operation = transition.state
      actions += transition.actions
    }
    actions += applySession(.credentialRejected, guards: .allSatisfied)
    requiresUserIntent = true
    return RappSecurityOutcome(actions: actions)
  }

  /// Rule X-01: a pairing leaving paired with a live session closes it.
  internal mutating func forgetPairing() -> RappSecurityOutcome {
    var actions = closeActiveOperation()
    if session.carriesAuthenticatedTraffic {
      actions += applySession(.closeRequestedByPairing, guards: .allSatisfied)
    }
    actions += applyPairing(.forgetPairing, guards: .allSatisfied)
    return RappSecurityOutcome(actions: actions)
  }
}
