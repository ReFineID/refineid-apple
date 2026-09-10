// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// 3. At-most-once card safety
internal func step3() throws {
  // MARK: - 3. At-most-once card safety
  try commitDurableBeforeTransmission()
  try secondTransmissionRefused()
  try failedWriteHandsOutNothing()
  try ambiguousCompletionTerminal()
  try cancelBeforeTransmission()
  try cancelAdvisoryAfterTransmission()
}

/// The commit reaches storage before anything is handed to the card.
private func commitDurableBeforeTransmission() throws {
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
}
/// A second card command after a commit, and a second journal transmission, are refused.
private func secondTransmissionRefused() throws {
  var store = OperationJournalStore()
  var transaction = try AuthorizationTransaction(request: try browserRequest())
  try executeToCard(&transaction, &store)
  let pending = try transaction.beginCardCommand(to: &store)
  _ = pending.execute { $0 }

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
/// A durable write that fails hands out no command at all.
private func failedWriteHandsOutNothing() throws {
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
/// An ambiguous completion is reported, never retried.
private func ambiguousCompletionTerminal() throws {
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
/// A failure proven to precede transmission cancels cleanly.
private func cancelBeforeTransmission() throws {
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
/// Once a transmission may have started, a cancellation is advisory only.
private func cancelAdvisoryAfterTransmission() throws {
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
/// 6. Journal recovery and result redelivery
internal func step6() throws {
  // MARK: - 6. Journal recovery and result redelivery
  try interruptedRecoveryAmbiguous()
  try retainedResultUntilAcknowledged()
  try acknowledgementEchoesOperation()
  try safeReadDirect()
  try commitDeadlineEnforced()
}

/// An interrupted operation recovers as ambiguous, never as retryable.
private func interruptedRecoveryAmbiguous() throws {
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
/// A retained result stays available until it is acknowledged.
private func retainedResultUntilAcknowledged() throws {
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
}
/// An acknowledgement must echo the operation it acknowledges.
private func acknowledgementEchoesOperation() throws {
  var store = OperationJournalStore()
  var transaction = try AuthorizationTransaction(request: try browserRequest())
  try executeToCard(&transaction, &store)
  let pending = try transaction.beginCardCommand(to: &store)
  _ = pending.execute { $0 }
  let completed = OperationResultMessage.completed(
    reference: transaction.reference, result: .signature(OperationFixture.signature))
  try transaction.finishCompleted(to: &store, result: completed)

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
/// A safe read answers directly, with no prepare, commit, or transmission.
private func safeReadDirect() throws {
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
/// Expiry is enforced against the local monotonic deadline; a commit echoes its operation.
private func commitDeadlineEnforced() throws {
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
