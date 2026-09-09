// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Testing

@testable import RappEngine

@Suite("RAPP state invariants")
internal struct StateInvariantTests {
  private func connected(_ role: EndpointRole) -> RappState {
    var endpoint = RappState(role: role)
    endpoint.pairing = .pairedConnected
    endpoint.session = .healthy
    return endpoint
  }

  @Test("Admission needs a stored pairing and a healthy session")
  internal func admissionNeedsPairedAndHealthy() {
    #expect(connected(.proxy).operationAdmissionPermitted)
  }

  @Test("No admission without a healthy session")
  internal func noAdmissionWithoutHealthySession() {
    var idle = RappState(role: .proxy)
    idle.pairing = .pairedDisconnected
    #expect(!idle.operationAdmissionPermitted)
  }

  @Test("Unattributable input never revokes the pairing")
  internal func unattributableInputPreservesPairing() {
    var endpoint = connected(.proxy)
    _ = endpoint.sessionIntegrityFailed()
    #expect(endpoint.pairing == .pairedConnected)
    #expect(endpoint.session == .closing)
  }

  @Test("An authenticated violation revokes a stored pairing")
  internal func authenticatedViolationRevokesStoredPairing() {
    var endpoint = connected(.proxy)
    _ = endpoint.authenticatedProtocolViolation()
    #expect(endpoint.pairing == .revoked)
  }

  @Test("A violation before storage aborts the attempt only")
  internal func violationBeforeStorageAbortsTheAttempt() {
    var attempt = RappState(role: .proxy)
    attempt.pairing = .confirming
    _ = attempt.authenticatedProtocolViolation()
    #expect(attempt.pairing == .unpaired)
  }

  @Test("A credential rejection ends the operation and closes the session")
  internal func credentialRejectionEndsOperationAndSession() {
    var endpoint = connected(.proxy)
    endpoint.operation = .executing
    let outcome = endpoint.credentialRejected()
    #expect(endpoint.operation == .credentialRejected)
    #expect(endpoint.session == .closing)
    #expect(outcome.actions.contains(.revokePairAfterCredentialRejection))
  }

  @Test("A committed operation becomes ambiguous on the requester")
  internal func committedOperationBecomesAmbiguous() {
    var endpoint = connected(.requester)
    endpoint.operation = .committed
    _ = endpoint.forgetPairing()
    #expect(endpoint.operation == .ambiguous)
  }

  @Test("A healthy session connects the pairing")
  internal func healthySessionConnectsThePairing() {
    var flow = RappState(role: .requester)
    flow.pairing = .pairedDisconnected
    flow.session =
      SessionState.transition(from: .authenticating, on: .readyVerified, role: .requester)?.state
      ?? .absent
    flow.pairing =
      PairingState.transition(from: flow.pairing, on: .sessionHealthy, role: .requester)?.state
      ?? flow.pairing
    #expect(flow.pairing == .pairedConnected)
    #expect(flow.session == .healthy)
  }
}
