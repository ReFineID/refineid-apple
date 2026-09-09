// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Both engines answer each other over an in-memory channel

import Foundation
import Testing

@testable import RappEngine

// Each drive runs as one continuous sequence, because that is what it
// proves: each step depends on the state the previous one left, and a peer
// answers a real predecessor rather than a fixture.
@Suite("RAPP proxy and requester engines")
internal struct EngineDriveTests {
  @Test("One operation completes end to end, transmitting exactly once")
  internal func happyPathCompletes() throws {
    let happy = try driveHappyPath()
    // Proving the at-most-once check is real: counting every journal write
    // as a transmission would let the happy path look like two.
    EngineReport.check(
      happy.store.proxyWrites.count > 1 && happy.store.transmissionsRecorded == 1,
      "several journal writes occurred but exactly one was a transmission")
  }

  @Test("A second request while one is live is refused as busy")
  internal func secondRequestIsBusy() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(
      grantedProfiles: [.authentication, .cardStatus], recovered: [])
    let first = try engineRequest(operation: signingOperation())
    _ = try proxy.receive(
      .operationRequest(first), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    let statesBefore = proxy.liveOperationStates
    let second = try engineRequest(
      operation: .inspectCard, operationIdentifier: EngineFixture.secondOperationIdentifier)
    let refusal = try proxy.receive(
      .operationRequest(second), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    EngineReport.check(refusal == .send(.error(.busy)), "a second request is refused as busy")
    EngineReport.check(
      proxy.liveOperationStates == statesBefore, "the refusal changed no operation state")
    EngineReport.check(
      ProtocolErrorMessage.busy.name == "busy", "the refusal uses the registered error name")
  }

  @Test("An ungranted profile is an authenticated violation")
  internal func ungrantedProfileIsRefused() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(grantedProfiles: [.cardStatus], recovered: [])
    let request = try engineRequest(operation: signingOperation())
    var refused = false
    do {
      _ = try proxy.receive(
        .operationRequest(request), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
        maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    } catch EngineError.authenticatedProtocolViolation(.profileNotGranted) {
      refused = true
    }
    EngineReport.check(refused, "an ungranted profile is an authenticated violation")
    EngineReport.check(
      proxy.liveOperationStates.isEmpty, "no operation was created for the refused request")
    EngineReport.check(
      store.proxyWrites.isEmpty, "nothing was journaled, so no card contact was possible")
  }

  @Test("A repeated commit is discarded and a replayed request is a violation")
  internal func duplicateCommitAndReplayedRequest() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(grantedProfiles: [.authentication], recovered: [])
    let request = try engineRequest(operation: signingOperation())
    let identifier = request.operationIdentifier
    _ = try proxy.receive(
      .operationRequest(request), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    try proxy.prerequisitesComplete(operationIdentifier: identifier)
    let approval = try UserApproval(
      for: request, approvedAtMilliseconds: EngineFixture.nowMilliseconds)
    _ = try proxy.approve(
      operationIdentifier: identifier, approval: approval,
      nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    let reference = try OperationReference(of: request)
    let firstCommit = try proxy.receive(
      .operationCommit(reference), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    EngineReport.check(
      firstCommit == .beginCardCommand(operationIdentifier: identifier),
      "the commit authorizes and records the one card command")
    EngineReport.check(
      store.transmissionsRecorded == 1, "storage records exactly one transmission")

    let repeated = try proxy.receive(
      .operationCommit(reference), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    EngineReport.check(
      repeated == .ignoredDuplicateCommit(operationIdentifier: identifier),
      "a repeated commit is discarded, not re-executed")
    EngineReport.check(
      store.transmissionsRecorded == 1, "storage still records exactly one transmission")

    var reused = false
    do {
      _ = try proxy.receive(
        .operationRequest(request), store: &store,
        nowMilliseconds: EngineFixture.nowMilliseconds,
        maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    } catch EngineError.authenticatedProtocolViolation(.activeOperationIdentifierReused) {
      reused = true
    }
    EngineReport.check(reused, "replaying the request for a live operation is a violation")
    EngineReport.check(
      store.transmissionsRecorded == 1, "the replay transmitted nothing further")
  }

  @Test("A mismatched result is a violation; an unknown one is a stale race")
  internal func wrongAndUnknownResults() throws {
    var store = MemoryJournalStore()
    var requester = RequesterOperationEngine(recovered: [])
    let request = try engineRequest(operation: signingOperation())
    _ = try requester.begin(request, store: &store)
    let reference = try OperationReference(of: request)
    // An identity body cannot answer a signing request.
    let wrong = OperationResultMessage.completed(
      reference: reference,
      result: .identity(
        displayName: EngineFixture.displayName, personIdentifier: EngineFixture.personIdentifier))
    var refused = false
    do {
      _ = try requester.receive(.operationResult(wrong), store: &store)
    } catch EngineError.authenticatedProtocolViolation(.invalidOperationMessage) {
      refused = true
    }
    EngineReport.check(refused, "a result that answers another operation is a violation")

    let foreign = OperationReference(
      operationIdentifier: EngineFixture.secondOperationIdentifier,
      requestHash: reference.requestHash)
    let unknown = try requester.receive(
      .operationResult(
        OperationResultMessage.completed(
          reference: foreign, result: .signature(EngineFixture.signature))),
      store: &store)
    EngineReport.check(
      unknown
        == .ignoredStale(
          operationIdentifier: EngineFixture.secondOperationIdentifier,
          response: .error(
            .unknownOperation(operationIdentifier: EngineFixture.secondOperationIdentifier))),
      "a result for an unknown operation is a stale-reference race")
  }

  @Test("Liveness traffic leaves the in-flight operation untouched")
  internal func livenessLeavesOperationsAlone() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(grantedProfiles: [.authentication], recovered: [])
    let request = try engineRequest(operation: signingOperation())
    let identifier = request.operationIdentifier
    _ = try proxy.receive(
      .operationRequest(request), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    let before = proxy.liveOperationStates[identifier]
    let liveness = try proxy.receive(
      .other(.livenessPing), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    EngineReport.check(
      liveness == .notOperation(.other(.livenessPing)),
      "liveness is not an operation message")
    EngineReport.check(
      proxy.liveOperationStates[identifier] == before,
      "liveness left the in-flight operation untouched")

    var model = RappState(role: .proxy)
    model.pairing = .pairedConnected
    model.session = .healthy
    model.operation = .prepared
    _ = model.livenessMissed()
    EngineReport.check(
      !model.operationAdmissionPermitted, "a missed probe blocks new operation admission")
    EngineReport.check(
      model.operation == .prepared, "a missed probe does not disturb the live operation")
    _ = model.livenessRestored()
    EngineReport.check(model.session == .healthy, "an exact echo restores the session")
  }

  @Test("A late commit expires instead of authorizing")
  internal func lateCommitExpires() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(grantedProfiles: [.authentication], recovered: [])
    let request = try engineRequest(operation: signingOperation())
    let identifier = request.operationIdentifier
    _ = try proxy.receive(
      .operationRequest(request), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    try proxy.prerequisitesComplete(operationIdentifier: identifier)
    let approval = try UserApproval(
      for: request, approvedAtMilliseconds: EngineFixture.nowMilliseconds)
    _ = try proxy.approve(
      operationIdentifier: identifier, approval: approval,
      nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    let reference = try OperationReference(of: request)
    let expired = try proxy.receive(
      .operationCommit(reference), store: &store,
      nowMilliseconds: EngineFixture.expiredNowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    guard case .send(.operationResult(let expiredResult)) = expired else {
      EngineReport.check(false, "a late commit answers with an expired result")
      return
    }
    EngineReport.check(
      expiredResult.error == .requestExpired, "a late commit is expired, not a violation")
    EngineReport.check(
      store.transmissionsRecorded == 0, "an expired commit transmitted nothing")
  }

  @Test("A failed durable write authorizes no card command")
  internal func failedWriteAuthorizesNothing() throws {
    var store = MemoryJournalStore()
    var proxy = ProxyOperationEngine(grantedProfiles: [.authentication], recovered: [])
    let request = try engineRequest(operation: signingOperation())
    let identifier = request.operationIdentifier
    _ = try proxy.receive(
      .operationRequest(request), store: &store, nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    try proxy.prerequisitesComplete(operationIdentifier: identifier)
    let approval = try UserApproval(
      for: request, approvedAtMilliseconds: EngineFixture.nowMilliseconds)
    _ = try proxy.approve(
      operationIdentifier: identifier, approval: approval,
      nowMilliseconds: EngineFixture.nowMilliseconds,
      maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    let reference = try OperationReference(of: request)
    store.failNextWrite = true
    var authorized = true
    do {
      _ = try proxy.receive(
        .operationCommit(reference), store: &store,
        nowMilliseconds: EngineFixture.nowMilliseconds,
        maximumLifetimeMilliseconds: EngineFixture.maximumLifetimeMilliseconds)
    } catch {
      authorized = false
    }
    EngineReport.check(!authorized, "a failed durable write authorizes no card command")
    EngineReport.check(
      store.transmissionsRecorded == 0,
      "no transmission is recorded when the write failed")
  }
}
