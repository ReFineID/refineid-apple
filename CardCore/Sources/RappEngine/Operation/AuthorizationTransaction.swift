// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One operation from validated request to durable terminal state.
///
/// The stage is authoritative before the durable commit; afterwards the
/// journal is, because only the journal survives a restart.
internal struct AuthorizationTransaction {
  internal let request: OperationRequest

  internal let requestHash: Data

  internal private(set) var journal: OperationJournal

  internal private(set) var stage: AuthorizationStage

  internal private(set) var retainedResult: OperationResultMessage?

  internal var reference: OperationReference {
    OperationReference(
      operationIdentifier: request.operationIdentifier, requestHash: requestHash)
  }

  /// The state the protocol shows for this operation.
  internal var operationState: OperationState {
    switch stage {
    case .requested:
      .requested

    case .awaitingConsent, .executingSafeRead:
      .awaitingConsent

    case .prepared:
      .prepared

    case .committed:
      .committed

    case .executing:
      .executing

    case .resultPending:
      .resultPending

    case .terminal:
      journal.record.state
    }
  }

  /// Prepares an operation, persisting and transmitting nothing.
  internal init(request: OperationRequest) throws {
    let hash = try request.requestHash()
    self.request = request
    self.requestHash = hash
    self.journal = OperationJournal(
      pairIdentifier: request.pairIdentifier,
      sessionIdentifier: request.sessionIdentifier,
      operationIdentifier: request.operationIdentifier,
      requestHash: hash)
    self.stage = .requested
    self.retainedResult = nil
  }

  /// Records that the profile's bounded reads finished.
  ///
  /// Consent is not asked
  /// before this point.
  internal mutating func prerequisitesComplete() throws {
    guard stage == .requested else { throw AuthorizationError.wrongStage(stage: stage) }
    stage = .awaitingConsent
  }

  /// Accepts the holder's consent for this exact request.
  internal mutating func approve(
    _ approval: UserApproval,
    nowMilliseconds: UInt64,
    maximumLifetimeMilliseconds: UInt64
  ) throws -> ApprovalOutcome {
    guard stage == .awaitingConsent else { throw AuthorizationError.wrongStage(stage: stage) }
    try validate(
      approval, nowMilliseconds: nowMilliseconds,
      maximumLifetimeMilliseconds: maximumLifetimeMilliseconds)
    if request.operation.isConsequential {
      stage = .prepared
      return .prepared(reference)
    }
    stage = .executingSafeRead
    return .executeSafeRead(AuthorizedSafeRead(operation: request.operation))
  }

  /// Writes the point of no return, once the commit echoes this request and
  /// the request has not expired.
  internal mutating func commit(
    to store: inout some JournalStore,
    requesterCommit: OperationReference,
    nowMilliseconds: UInt64,
    maximumLifetimeMilliseconds: UInt64
  ) throws {
    guard stage == .prepared else { throw AuthorizationError.wrongStage(stage: stage) }
    guard requesterCommit == reference else { throw AuthorizationError.commitMismatch }
    let deadline = try deadlineMilliseconds(maximumLifetimeMilliseconds)
    guard nowMilliseconds <= deadline else { throw AuthorizationError.expired }
    try mapJournal { try journal.commit(to: &store, requestHash: requestHash) }
    stage = .committed
  }

  /// Records the single transmission and yields the one executable command.
  internal mutating func beginCardCommand(
    to store: inout some JournalStore
  ) throws -> PendingCardCommand<AuthorizedCardCommand> {
    guard stage == .committed else { throw AuthorizationError.wrongStage(stage: stage) }
    let command = AuthorizedCardCommand(operation: request.operation)
    // The one-shot command cannot travel through the generic journal mapper,
    // so this call maps its own failure.
    let pending: PendingCardCommand<AuthorizedCardCommand>
    do {
      pending = try journal.beginCardCommand(to: &store, command: command)
    } catch let error as JournalError {
      throw AuthorizationError.journal(error)
    }
    stage = .executing
    return pending
  }

  /// Retains a completed result before it may be released to the transport.
  internal mutating func finishCompleted(
    to store: inout some JournalStore, result: OperationResultMessage
  ) throws {
    guard result.status == .completed else { throw AuthorizationError.invalidResult }
    do {
      try result.validate(for: reference, operation: request.operation)
    } catch {
      throw AuthorizationError.invalidResult
    }
    switch stage {
    case .executing:
      try mapJournal { try journal.finishCompleted(to: &store, result: result) }

    case .executingSafeRead:
      try mapJournal { try journal.finishSafeReadCompleted(to: &store, result: result) }

    default:
      throw AuthorizationError.wrongStage(stage: stage)
    }
    retainedResult = result
    stage = .resultPending
  }

  /// Records a stable non-successful result from any legal stage.
  internal mutating func finishFailure(
    to store: inout some JournalStore, result: OperationResultMessage
  ) throws {
    guard result.status != .completed else { throw AuthorizationError.invalidResult }
    do {
      try result.validate(for: reference, operation: request.operation)
    } catch {
      throw AuthorizationError.invalidResult
    }
    guard let terminal = result.status.failureState else {
      throw AuthorizationError.invalidResult
    }
    switch stage {
    case .requested, .awaitingConsent, .prepared, .executingSafeRead:
      try mapJournal { try journal.finishSafeReadFailure(to: &store, state: terminal) }

    case .committed where terminal == .cancelled:
      try mapJournal { try journal.cancelCommittedBeforeTransmission(to: &store) }

    case .executing:
      try mapJournal { try journal.finish(to: &store, state: terminal) }

    default:
      throw AuthorizationError.wrongStage(stage: stage)
    }
    stage = .terminal
  }

  /// Applies a cancellation, classified by the durable commit boundary.
  ///
  /// After a transmission may have started the cancellation is advisory: the
  /// card may already have acted, and a silent retry would be a second use.
  internal mutating func receiveCancel(
    to store: inout some JournalStore,
    cancellation: OperationReference,
    transmissionProvenNotStarted: Bool
  ) throws -> ProxyCancelOutcome {
    guard cancellation == reference else { throw AuthorizationError.commitMismatch }
    switch stage {
    case .requested, .awaitingConsent, .prepared, .executingSafeRead:
      try mapJournal { try journal.finishSafeReadFailure(to: &store, state: .cancelled) }
      stage = .terminal
      return .cancelled

    case .committed where transmissionProvenNotStarted:
      try mapJournal { try journal.cancelCommittedBeforeTransmission(to: &store) }
      stage = .terminal
      return .cancelled

    case .committed, .executing, .resultPending:
      return .advisory

    case .terminal:
      throw AuthorizationError.wrongStage(stage: stage)
    }
  }

  /// Records the acknowledgement that releases the retained result.
  internal mutating func acknowledgeResult(
    to store: inout some JournalStore, acknowledgement: OperationReference
  ) throws {
    guard stage == .resultPending else { throw AuthorizationError.wrongStage(stage: stage) }
    guard acknowledgement == reference else { throw AuthorizationError.commitMismatch }
    try mapJournal { try journal.acknowledgeResult(to: &store) }
    retainedResult = nil
    stage = .terminal
  }

  /// Records that the session was lost after the result was sent.
  ///
  /// The result stays retained so it can be delivered again on request, but
  /// no automatic replay of the command or the result follows.
  internal mutating func deliveryBecameUncertain(
    to store: inout some JournalStore
  ) throws {
    guard stage == .resultPending else { throw AuthorizationError.wrongStage(stage: stage) }
    try mapJournal { try journal.markDeliveryUncertain(to: &store) }
    stage = .terminal
  }

  /// Resolves a record that a restart interrupted, without retrying it.
  internal mutating func recoverAfterCrash(to store: inout some JournalStore) throws {
    try mapJournal { try journal.recoverAfterCrash(to: &store) }
    stage = .terminal
  }

  private func deadlineMilliseconds(_ maximumLifetimeMilliseconds: UInt64) throws -> UInt64 {
    do {
      return try request.localDeadlineMilliseconds(
        maximumLifetimeMilliseconds: maximumLifetimeMilliseconds)
    } catch {
      throw AuthorizationError.expired
    }
  }

  private func validate(
    _ approval: UserApproval,
    nowMilliseconds: UInt64,
    maximumLifetimeMilliseconds: UInt64
  ) throws {
    guard approval.operationIdentifier == request.operationIdentifier,
      approval.requestHash == requestHash
    else { throw AuthorizationError.approvalMismatch }
    let deadline = try deadlineMilliseconds(maximumLifetimeMilliseconds)
    guard approval.approvedAtMilliseconds >= request.localStartMilliseconds,
      approval.approvedAtMilliseconds <= deadline,
      nowMilliseconds <= deadline
    else { throw AuthorizationError.expired }
  }

  private func mapJournal<Answer>(_ body: () throws -> Answer) throws -> Answer {
    do {
      return try body()
    } catch let error as JournalError {
      throw AuthorizationError.journal(error)
    }
  }
}
