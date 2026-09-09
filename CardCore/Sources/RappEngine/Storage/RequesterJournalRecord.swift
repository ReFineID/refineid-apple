// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Storage-format versions of the two operation journals.
internal let requesterJournalFormatVersion: UInt64 = 1

/// Requester's durable record of one operation.
internal struct RequesterJournalRecord: Equatable {
  internal var pairIdentifier: Data
  internal var sessionIdentifier: Data
  internal var operationIdentifier: Data
  internal var requestHash: Data
  internal var state: OperationState
  internal var retainedResult: CardOperationResult?
  internal var reconciliation: StatusReport?

  internal static func decode(_ bytes: Data) throws -> Self {
    var map = try decodedMap(bytes)
    guard try takeUnsigned(&map, "format_version") == requesterJournalFormatVersion else {
      throw PairRecordError.invalidInput
    }
    let decodedPairIdentifier = try takeBytes(&map, "pair_id")
    let decodedSessionIdentifier = try takeBytes(&map, "session_id")
    let decodedOperationIdentifier = try takeBytes(&map, "operation_id")
    let decodedRequestHash = try takeBytes(&map, "request_hash")
    guard decodedPairIdentifier.count == PairRecordSize.pairIdentifier,
      decodedSessionIdentifier.count == JournalSize.sessionIdentifier,
      decodedOperationIdentifier.count == JournalSize.operationIdentifier,
      decodedRequestHash.count == JournalSize.requestHash
    else { throw PairRecordError.invalidInput }
    guard let decodedState = OperationState(rawValue: try takeText(&map, "state")) else {
      throw PairRecordError.invalidInput
    }
    let decodedRetainedResult: CardOperationResult?
    switch try takeStoredValue(&map, "retained_result") {
    case .null:
      decodedRetainedResult = nil

    case let value:
      decodedRetainedResult = try journalResultFrom(value)
    }
    let decodedReconciliation: StatusReport?
    switch try takeStoredValue(&map, "reconciliation") {
    case .null:
      decodedReconciliation = nil

    case let value:
      decodedReconciliation = try statusReportFrom(value)
    }
    guard map.isEmpty else { throw PairRecordError.invalidInput }
    return Self(
      pairIdentifier: decodedPairIdentifier,
      sessionIdentifier: decodedSessionIdentifier,
      operationIdentifier: decodedOperationIdentifier,
      requestHash: decodedRequestHash,
      state: decodedState,
      retainedResult: decodedRetainedResult,
      reconciliation: decodedReconciliation
    )
  }

  internal func encoded() throws -> Data {
    let value = WireValue.map([
      "format_version": .unsigned(requesterJournalFormatVersion),
      "pair_id": .bytes(pairIdentifier),
      "session_id": .bytes(sessionIdentifier),
      "operation_id": .bytes(operationIdentifier),
      "request_hash": .bytes(requestHash),
      "state": .text(state.rawValue),
      "retained_result": retainedResult.map(journalResultValue) ?? .null,
      "reconciliation": reconciliation.map(statusReportValue) ?? .null,
    ])
    do {
      return try value.encoded()
    } catch {
      throw PairRecordError.invalidInput
    }
  }
}
