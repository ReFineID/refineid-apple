// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Typed operations, hash-bound approval, and at-most-once card safety

import Foundation
import Testing

@testable import RappEngine

// Known-answer harness for the operation layer. It drives the authorization
// transaction, its journal, and the state tables, and prints one line per
// check.

private func check(_ name: String, _ condition: Bool) {
  #expect(condition, "\(name)")
}

private func browserRequest(
  operationIdentifier: Data = OperationFixture.operationIdentifier,
  sessionIdentifier: Data = OperationFixture.sessionIdentifier,
  origin: String = OperationFixture.origin,
  keyProfile: CardKeyProfile = .ecdsaP256,
  algorithm: SignatureAlgorithm = .ecdsaSha256,
  digest: Data = OperationFixture.digest
) throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: sessionIdentifier,
    profile: .authentication,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: .browserAuthenticate(
      origin: origin, keyProfile: keyProfile, algorithm: algorithm, digest: digest))
}

private func identityRequest() throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    profile: .cardStatus,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: .readIdentity)
}

/// Drives a consequential operation to the point where the card would act.
private func executeToCard(
  _ transaction: inout AuthorizationTransaction, _ store: inout OperationJournalStore
) throws {
  try transaction.prerequisitesComplete()
  let approval = try UserApproval(
    for: transaction.request, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
  _ = try transaction.approve(
    approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
    maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
  try transaction.commit(
    to: &store, requesterCommit: transaction.reference,
    nowMilliseconds: OperationFixture.approvalMilliseconds,
    maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
}

private func hexText(_ bytes: Data) -> String {
  bytes.map { String(format: "%02x", $0) }.joined()
}

private func fixedRequest(
  profile: ProfileName, operation: CardOperation
) throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    profile: profile,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: operation)
}

/// 0. The registry agrees with the reference engine byte for byte
private func step0() throws {
  let browser = try fixedRequest(
    profile: .authentication,
    operation: .browserAuthenticate(
      origin: OperationFixture.origin, keyProfile: .ecdsaP256, algorithm: .ecdsaSha256,
      digest: OperationFixture.digest))
  check(
    "browser authentication hashes to the reference value",
    hexText(try browser.requestHash()) == ReferenceOperation.browserHash)
  check(
    "the browser request body is byte-exact",
    hexText(try WireValue.map(try browser.wireBody()).encoded())
      == ReferenceOperation.browserBody)

  let sign = try fixedRequest(
    profile: .documentSigning,
    operation: .signDocument(
      documentName: "Contract.pdf", keyProfile: .rsa3072, algorithm: .rsaPkcs1Sha256,
      digest: OperationFixture.digest))
  check(
    "document signing hashes to the reference value",
    hexText(try sign.requestHash()) == ReferenceOperation.signHash)

  let identity = try fixedRequest(profile: .cardStatus, operation: .readIdentity)
  check(
    "reading the identity hashes to the reference value",
    hexText(try identity.requestHash()) == ReferenceOperation.identityHash)

  let certificate = try fixedRequest(
    profile: .documentSigning, operation: .readCertificate(kind: .signature))
  check(
    "reading a certificate hashes to the reference value",
    hexText(try certificate.requestHash()) == ReferenceOperation.certificateHash)

  let inspect = try fixedRequest(profile: .cardStatus, operation: .inspectCard)
  check(
    "inspecting the card hashes to the reference value",
    hexText(try inspect.requestHash()) == ReferenceOperation.inspectHash)
}

/// 1. The request hash binds every field
private func step1() throws {
  // MARK: - 1. The request hash binds every field
  do {
    let base = try browserRequest()
    let baseHash = try base.requestHash()

    check(
      "changing the origin changes the hash",
      try browserRequest(origin: "https://other.test").requestHash() != baseHash)
    check(
      "changing the digest changes the hash",
      try browserRequest(digest: OperationFixture.otherDigest).requestHash() != baseHash)
    check(
      "changing the algorithm changes the hash",
      try browserRequest(
        keyProfile: .ecdsaP384, algorithm: .ecdsaSha384,
        digest: Data(repeating: OperationFill.digest, count: DigestLength.sha384)
      ).requestHash() != baseHash)
    check(
      "changing the session changes the hash",
      try browserRequest(sessionIdentifier: OperationFixture.otherSession).requestHash() != baseHash
    )
    check(
      "changing the operation identifier changes the hash",
      try browserRequest(operationIdentifier: OperationFixture.otherOperation).requestHash()
        != baseHash)
    check("the same request hashes the same", try browserRequest().requestHash() == baseHash)

    // An approval names the hash it approved, so it cannot travel.
    let approval = try UserApproval(
      for: base, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
    var other = try AuthorizationTransaction(
      request: try browserRequest(digest: OperationFixture.otherDigest))
    try other.prerequisitesComplete()
    var moved = false
    do {
      _ = try other.approve(
        approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
        maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
      moved = true
    } catch AuthorizationError.approvalMismatch {
      moved = false
    }
    check("an approval does not authorize a different request", !moved)

    // The wire body carries the hash, and a receiver recomputes it.
    let parsed = try OperationRequest.from(
      wireBody: try base.wireBody(),
      pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      localStartMilliseconds: OperationFixture.startMilliseconds)
    check("a request round-trips through its wire body", parsed == base)

    var tampered = try base.wireBody()
    tampered["request_hash"] = .bytes(
      Data(repeating: OperationFill.tamperedHash, count: OperationSize.requestHash))
    var acceptedTamper = false
    do {
      _ = try OperationRequest.from(
        wireBody: tampered, pairIdentifier: OperationFixture.pairIdentifier,
        sessionIdentifier: OperationFixture.sessionIdentifier,
        localStartMilliseconds: OperationFixture.startMilliseconds)
      acceptedTamper = true
    } catch CardOperationError.requestHashMismatch {
      acceptedTamper = false
    }
    check("a request whose hash does not cover it is refused", !acceptedTamper)
  }
}

/// 2. Grant enforcement and registry refusals
private func step2() throws {
  // MARK: - 2. Grant enforcement and registry refusals
  do {
    let request = try browserRequest()
    var refused = false
    do {
      try request.requireGranted(by: [.cardStatus, .documentSigning])
    } catch CardOperationError.profileNotGranted {
      refused = true
    }
    check("an ungranted profile is refused before any card contact", refused)

    var permitted = true
    do {
      try request.requireGranted(by: [.authentication])
    } catch {
      permitted = false
    }
    check("a granted profile is admitted", permitted)

    // The profile must own the action it names.
    var mismatched = false
    do {
      _ = try OperationRequest(
        operationIdentifier: OperationFixture.operationIdentifier,
        pairIdentifier: OperationFixture.pairIdentifier,
        sessionIdentifier: OperationFixture.sessionIdentifier,
        profile: .cardStatus,
        localStartMilliseconds: OperationFixture.startMilliseconds,
        expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
        operation: .browserAuthenticate(
          origin: OperationFixture.origin, keyProfile: .ecdsaP256, algorithm: .ecdsaSha256,
          digest: OperationFixture.digest))
    } catch CardOperationError.profileActionMismatch {
      mismatched = true
    }
    check("a profile that does not own the action is refused", mismatched)

    var unknown = false
    do {
      _ = try CardOperation.from(action: "transmit_apdu", context: [:], payload: [:])
    } catch CardOperationError.unknownAction {
      unknown = true
    }
    check("an unregistered action is refused", unknown)

    var extraField = false
    do {
      _ = try CardOperation.from(
        action: "read_identity", context: [:], payload: ["apdu": .bytes(Data([0x00]))])
    } catch CardOperationError.unexpectedField {
      extraField = true
    }
    check("an unregistered field is refused", extraField)

    var wrongDigest = false
    do {
      _ = try CardOperation.from(
        action: "browser_authenticate",
        context: ["origin": .text(OperationFixture.origin)],
        payload: [
          "key_profile": .text(CardKeyProfile.ecdsaP256.rawValue),
          "algorithm": .text(SignatureAlgorithm.ecdsaSha256.rawValue),
          "digest": .bytes(Data(repeating: 0x01, count: DigestLength.sha384)),
        ])
    } catch CardOperationError.wrongDigestLength {
      wrongDigest = true
    }
    check("a digest of the wrong length is refused", wrongDigest)

    var crossFamily = false
    do {
      _ = try CardOperation.from(
        action: "browser_authenticate",
        context: ["origin": .text(OperationFixture.origin)],
        payload: [
          "key_profile": .text(CardKeyProfile.rsa3072.rawValue),
          "algorithm": .text(SignatureAlgorithm.ecdsaSha256.rawValue),
          "digest": .bytes(OperationFixture.digest),
        ])
    } catch CardOperationError.keyAlgorithmMismatch {
      crossFamily = true
    }
    check("an elliptic scheme on an RSA key is refused", crossFamily)

    var emptyContext = false
    do {
      _ = try CardOperation.from(
        action: "sign_document",
        context: ["document_name": .text("   ")],
        payload: [
          "key_profile": .text(CardKeyProfile.rsa3072.rawValue),
          "algorithm": .text(SignatureAlgorithm.rsaPkcs1Sha256.rawValue),
          "digest": .bytes(OperationFixture.digest),
        ])
    } catch CardOperationError.invalidDisplayContext {
      emptyContext = true
    }
    check("an unpresentable request is refused", emptyContext)
  }
}

/// 3. At-most-once card safety
private func step3() throws {
  // MARK: - 3. At-most-once card safety
  do {
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)

    // The commit reaches storage before anything is handed to the card.
    check(
      "the commit is durable before any transmission",
      store.writes.last?.state == .committed
        && store.writes.last?.transmissionCount == TransmissionCount.untransmitted)

    let pending = try transaction.beginCardCommand(to: &store)
    check(
      "the transmission is recorded before the command is exposed",
      store.writes.last?.state == .executing
        && store.writes.last?.transmissionCount == TransmissionCount.single)

    let executed = pending.execute { command -> CardOperation in command.operation }
    check("the command carries the approved operation", executed == transaction.request.operation)
    check("exactly one transmission is recorded", store.recordedTransmissions == 1)

    // A second command from the same transaction is refused.
    var second = false
    do {
      _ = try transaction.beginCardCommand(to: &store)
      second = true
    } catch AuthorizationError.wrongStage {
      second = false
    }
    check("a second card command after a commit is refused", !second)

    // The journal refuses a second transmission even when driven directly.
    var journal = OperationJournal(
      pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      operationIdentifier: OperationFixture.operationIdentifier,
      requestHash: try browserRequest().requestHash())
    var direct = OperationJournalStore()
    try journal.commit(to: &direct, requestHash: try browserRequest().requestHash())
    let first = try journal.beginCardCommand(to: &direct, command: "one-shot")
    _ = first.execute { $0 }
    var journalSecond = false
    do {
      _ = try journal.beginCardCommand(to: &direct, command: "one-shot")
      journalSecond = true
    } catch JournalError.invalidState {
      journalSecond = false
    }
    check("the journal refuses a second transmission", !journalSecond)
  }

  do {
    // A durable write that fails hands out no command at all.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    store.failNextWrite = true
    var handedOut = false
    do {
      _ = try transaction.beginCardCommand(to: &store)
      handedOut = true
    } catch AuthorizationError.journal(.persistence) {
      handedOut = false
    }
    check("a failed durable write yields no command", !handedOut)
    check("no transmission is recorded after a failed write", store.recordedTransmissions == 0)
  }

  do {
    // An ambiguous completion is reported, never retried.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }

    let ambiguous = OperationResultMessage.failure(
      reference: transaction.reference, error: .cardCompletionAmbiguous)
    try transaction.finishFailure(to: &store, result: ambiguous)
    check("an ambiguous completion is terminal", transaction.operationState == .ambiguous)
    check(
      "an ambiguous record forbids automatic retry",
      store.writes.last?.automaticRetryPermitted == false)
    check(
      "the ambiguous record keeps its transmission count",
      store.writes.last?.transmissionCount == TransmissionCount.single)

    var retried = false
    do {
      _ = try transaction.beginCardCommand(to: &store)
      retried = true
    } catch AuthorizationError.wrongStage {
      retried = false
    }
    check("an ambiguous operation cannot be retried", !retried)
  }

  do {
    // A failure proven to precede transmission cancels cleanly.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let outcome = try transaction.receiveCancel(
      to: &store, cancellation: transaction.reference, transmissionProvenNotStarted: true)
    check("a cancellation before transmission cancels the operation", outcome == .cancelled)
    check("the cancelled record shows no transmission", store.recordedTransmissions == 0)
    check("the operation is cancelled", transaction.operationState == .cancelled)
  }

  do {
    // Once a transmission may have started, a cancellation is advisory only.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }
    let outcome = try transaction.receiveCancel(
      to: &store, cancellation: transaction.reference, transmissionProvenNotStarted: false)
    check("a cancellation after transmission is advisory", outcome == .advisory)
    check("the operation continues to its own terminal state", transaction.stage == .executing)
  }
}

/// 4. Results
private func step4() throws {
  // MARK: - 4. Results
  do {
    let transaction = try AuthorizationTransaction(request: try browserRequest())
    let completed = OperationResultMessage.completed(
      reference: transaction.reference, result: .signature(OperationFixture.signature))
    let encoded = try completed.encoded()
    check("a completed result round-trips", try OperationResultMessage.decode(encoded) == completed)

    var validated = true
    do {
      try completed.validate(for: transaction.reference, operation: transaction.request.operation)
    } catch {
      validated = false
    }
    check("a signature answers a browser authentication", validated)

    // A body that answers a different operation is refused.
    let wrongShape = OperationResultMessage.completed(
      reference: transaction.reference, result: .certificate(OperationFixture.certificate))
    var wrongAccepted = false
    do {
      try wrongShape.validate(
        for: transaction.reference, operation: transaction.request.operation)
      wrongAccepted = true
    } catch CardOperationError.profileActionMismatch {
      wrongAccepted = false
    }
    check("a result that answers another operation is refused", !wrongAccepted)

    // A completed result must carry an output.
    let emptyCompleted = OperationResultMessage(
      operationIdentifier: transaction.reference.operationIdentifier,
      requestHash: transaction.reference.requestHash,
      status: .completed,
      error: nil,
      result: nil)
    var emptyAccepted = false
    do {
      try emptyCompleted.validate(
        for: transaction.reference, operation: transaction.request.operation)
      emptyAccepted = true
    } catch CardOperationError.invalidField {
      emptyAccepted = false
    }
    check("a completed result carrying no output is refused", !emptyAccepted)

    var decodedEmpty = false
    do {
      _ = try OperationResultMessage.decode(try emptyCompleted.encoded())
      decodedEmpty = true
    } catch {
      decodedEmpty = false
    }
    check("a completed result with an empty body does not decode", !decodedEmpty)

    // Every registered failure names exactly one status.
    var registryHolds = true
    for error in [
      ResultError.userDenied, .requestExpired, .cancelled, .requestInvalidOrUnsupported,
      .retryPolicyRefused, .credentialRejected, .cardRemovedBeforeTransmit,
      .cardCompletionAmbiguous,
    ] {
      let message = OperationResultMessage.failure(
        reference: transaction.reference, error: error)
      if message.status != error.status { registryHolds = false }
      if (try? OperationResultMessage.decode(try message.encoded())) != message {
        registryHolds = false
      }
    }
    check("every registered failure round-trips under its own status", registryHolds)

    // A failure whose name contradicts its status is refused.
    let contradictory = OperationResultMessage(
      operationIdentifier: transaction.reference.operationIdentifier,
      requestHash: transaction.reference.requestHash,
      status: .denied,
      error: .cardCompletionAmbiguous,
      result: nil)
    var contradictionAccepted = false
    do {
      try contradictory.validate(
        for: transaction.reference, operation: transaction.request.operation)
      contradictionAccepted = true
    } catch CardOperationError.invalidField {
      contradictionAccepted = false
    }
    check("a failure name that contradicts its status is refused", !contradictionAccepted)

    // A result for another operation does not satisfy this reference.
    let foreign = OperationResultMessage.completed(
      reference: OperationReference(
        operationIdentifier: OperationFixture.otherOperation,
        requestHash: transaction.reference.requestHash),
      result: .signature(OperationFixture.signature))
    var foreignAccepted = false
    do {
      try foreign.validate(for: transaction.reference, operation: transaction.request.operation)
      foreignAccepted = true
    } catch CardOperationError.requestHashMismatch {
      foreignAccepted = false
    }
    check("a result bound to another operation is refused", !foreignAccepted)
  }
}

/// 5. Credential rejection through the state tables
private func step5() throws {
  // MARK: - 5. Credential rejection through the state tables
  do {
    var state = RappState(role: .proxy)
    state.pairing = .pairedConnected
    state.session = .healthy
    state.operation = .executing

    let outcome = state.credentialRejected()
    check("the operation ends as credential rejected", state.operation == .credentialRejected)
    check("the session leaves healthy", state.session != .healthy)
    check(
      "the pair is revoked after a credential rejection",
      outcome.actions.contains(.revokePairAfterCredentialRejection))
    check(
      "the rejected credential and its derived state are removed",
      outcome.actions.contains(.removeRejectedCredentialAndDerivedState))
    check("a fresh explicit user action is required", state.requiresUserIntent)

    // The same rejection travels through the authorization transaction.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }
    let rejected = OperationResultMessage.failure(
      reference: transaction.reference, error: .credentialRejected)
    try transaction.finishFailure(to: &store, result: rejected)
    check(
      "a credential rejection is a terminal operation state",
      transaction.operationState == .credentialRejected)
    check(
      "a credential rejection forbids automatic retry",
      store.writes.last?.automaticRetryPermitted == false)
  }
}

/// 6. Journal recovery and result redelivery
private func step6() throws {
  // MARK: - 6. Journal recovery and result redelivery
  do {
    // An interrupted operation recovers as ambiguous, never as retryable.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }

    let interrupted = try #require(store.writes.last, "an interrupted record exists")
    var recovered = OperationJournal(recovered: interrupted)
    var afterRestart = OperationJournalStore()
    try recovered.recoverAfterCrash(to: &afterRestart)
    check("an interrupted operation recovers as ambiguous", recovered.record.state == .ambiguous)
    check(
      "a recovered operation is never retryable",
      recovered.record.automaticRetryPermitted == false)
    check(
      "recovery keeps the transmission it may have made",
      recovered.record.transmissionCount == TransmissionCount.single)

    // A committed but untransmitted record is equally ambiguous: the commit
    // alone does not prove the card was left untouched.
    var committedOnly = OperationJournal(
      pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      operationIdentifier: OperationFixture.operationIdentifier,
      requestHash: try browserRequest().requestHash())
    var committedStore = OperationJournalStore()
    try committedOnly.commit(
      to: &committedStore, requestHash: try browserRequest().requestHash())
    try committedOnly.recoverAfterCrash(to: &committedStore)
    check(
      "a committed record recovers as ambiguous", committedOnly.record.state == .ambiguous)

    // A terminal record is not a recovery candidate.
    var terminalRecovery = false
    do {
      try committedOnly.recoverAfterCrash(to: &committedStore)
      terminalRecovery = true
    } catch JournalError.invalidState {
      terminalRecovery = false
    }
    check("a terminal record is not recovered again", !terminalRecovery)
  }

  do {
    // A retained result stays available until it is acknowledged.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }
    let completed = OperationResultMessage.completed(
      reference: transaction.reference, result: .signature(OperationFixture.signature))
    try transaction.finishCompleted(to: &store, result: completed)

    check("a completed result is retained", transaction.retainedResult == completed)
    check(
      "the retained result is durable",
      store.retained[OperationFixture.operationIdentifier] == completed)
    check("the operation awaits acknowledgement", transaction.operationState == .resultPending)

    // Losing the session keeps the result but forbids replay.
    var uncertain = transaction
    var uncertainStore = store
    try uncertain.deliveryBecameUncertain(to: &uncertainStore)
    check(
      "an uncertain delivery keeps the result", uncertain.operationState == .deliveryUncertain)
    check("the result survives an uncertain delivery", uncertainStore.uncertain == 1)
    check(
      "an uncertain delivery forbids automatic retry",
      uncertainStore.writes.last?.automaticRetryPermitted == false)

    // An acknowledgement must echo the operation it acknowledges.
    var wrongAck = false
    do {
      try transaction.acknowledgeResult(
        to: &store,
        acknowledgement: OperationReference(
          operationIdentifier: OperationFixture.otherOperation,
          requestHash: transaction.reference.requestHash))
      wrongAck = true
    } catch AuthorizationError.commitMismatch {
      wrongAck = false
    }
    check("an acknowledgement for another operation is refused", !wrongAck)

    try transaction.acknowledgeResult(to: &store, acknowledgement: transaction.reference)
    check("acknowledgement completes the operation", transaction.operationState == .completed)
    check("acknowledgement releases the retained result", transaction.retainedResult == nil)
    check(
      "the durable result is erased", store.retained[OperationFixture.operationIdentifier] == nil)
  }

  do {
    // A safe read answers directly, with no prepare, commit, or transmission.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try identityRequest())
    try transaction.prerequisitesComplete()
    let approval = try UserApproval(
      for: transaction.request, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
    let outcome = try transaction.approve(
      approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
      maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    check(
      "a safe read executes without prepare and commit",
      outcome == .executeSafeRead(AuthorizedSafeRead(operation: .readIdentity)))

    let result = OperationResultMessage.completed(
      reference: transaction.reference,
      result: .identity(displayName: "Holder", personIdentifier: "identifier"))
    try transaction.finishCompleted(to: &store, result: result)
    check("a safe read records no transmission", store.recordedTransmissions == 0)
    try transaction.acknowledgeResult(to: &store, acknowledgement: transaction.reference)
    check("a safe read completes on acknowledgement", transaction.operationState == .completed)
  }

  do {
    // Expiry is enforced against the local monotonic deadline.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try transaction.prerequisitesComplete()
    let approval = try UserApproval(
      for: transaction.request, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
    _ = try transaction.approve(
      approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
      maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    let deadline = try transaction.request.localDeadlineMilliseconds(
      maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    var expired = false
    do {
      try transaction.commit(
        to: &store, requesterCommit: transaction.reference,
        nowMilliseconds: deadline + 1,
        maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    } catch AuthorizationError.expired {
      expired = true
    }
    check("a commit after the deadline is refused", expired)
    check("an expired commit writes nothing", store.writes.isEmpty)

    // A commit must echo the prepared operation.
    var mismatch = false
    do {
      try transaction.commit(
        to: &store,
        requesterCommit: OperationReference(
          operationIdentifier: OperationFixture.otherOperation,
          requestHash: transaction.reference.requestHash),
        nowMilliseconds: OperationFixture.approvalMilliseconds,
        maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    } catch AuthorizationError.commitMismatch {
      mismatch = true
    }
    check("a commit that echoes another operation is refused", mismatch)
  }
}

/// Negative control.
private func step7() throws {
  // MARK: - Negative control
  do {
    // Permitting a second transmission must break the at-most-once check, so
    // the harness is shown to be measuring something.
    var store = OperationJournalStore()
    var journal = OperationJournal(
      pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      operationIdentifier: OperationFixture.operationIdentifier,
      requestHash: try browserRequest().requestHash())
    try journal.commit(to: &store, requestHash: try browserRequest().requestHash())
    let first = try journal.beginCardCommand(to: &store, command: "one-shot")
    _ = first.execute { $0 }

    // Rewind the durable record to committed, which is what a broken
    // implementation that forgot the transmission count would leave behind.
    var rewound = OperationJournal(
      recovered: ProxyJournalRecord(
        pairIdentifier: OperationFixture.pairIdentifier,
        sessionIdentifier: OperationFixture.sessionIdentifier,
        operationIdentifier: OperationFixture.operationIdentifier,
        requestHash: try browserRequest().requestHash(),
        state: .committed,
        transmissionCount: TransmissionCount.untransmitted,
        automaticRetryPermitted: true))
    let second = try rewound.beginCardCommand(to: &store, command: "one-shot")
    _ = second.execute { $0 }
    check(
      "a rewound record would transmit twice, so the check is real",
      store.writes.filter { record in record.state == .executing }.count
        == OperationFill.expectedExecutingWrites)
  }
}

// The scenario runs as one continuous drive, because that is what it proves:
// each step depends on the state the previous one left, and a peer answers a
// real predecessor rather than a fixture. Splitting it into separate tests
// would thread that state through setup and stop testing the sequence.
@Suite("RAPP operations and authorization")
internal struct OperationDriveTests {
  @Test("Typed operations, hash-bound approval, and at-most-once card safety")
  internal func run() throws {
    try step0()
    try step1()
    try step2()
    try step3()
    try step4()
    try step5()
    try step6()
    try step7()
  }
}
