// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

internal let proxyJournalFormatVersion: UInt64 = 1

/// Proxy's durable record of one operation, carrying the transmission count
/// that makes a card command at most once.
internal struct ProxyJournalRecord: Equatable {
  internal var pairIdentifier: Data
  internal var sessionIdentifier: Data
  internal var operationIdentifier: Data
  internal var requestHash: Data
  internal var state: OperationState
  internal var transmissionCount: UInt8
  internal var automaticRetryPermitted: Bool

  internal static func decode(_ bytes: Data) throws -> Self {
    var map = try decodedMap(bytes)
    guard try takeUnsigned(&map, "format_version") == proxyJournalFormatVersion else {
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
    let transmissions = try takeUnsigned(&map, "transmission_count")
    guard let decodedTransmissionCount = UInt8(exactly: transmissions)
    else { throw PairRecordError.invalidInput }
    let decodedAutomaticRetryPermitted = try takeBoolean(&map, "automatic_retry_permitted")
    guard map.isEmpty else { throw PairRecordError.invalidInput }
    return Self(
      pairIdentifier: decodedPairIdentifier,
      sessionIdentifier: decodedSessionIdentifier,
      operationIdentifier: decodedOperationIdentifier,
      requestHash: decodedRequestHash,
      state: decodedState,
      transmissionCount: decodedTransmissionCount,
      automaticRetryPermitted: decodedAutomaticRetryPermitted
    )
  }

  internal func encoded() throws -> Data {
    let value = WireValue.map([
      "format_version": .unsigned(proxyJournalFormatVersion),
      "pair_id": .bytes(pairIdentifier),
      "session_id": .bytes(sessionIdentifier),
      "operation_id": .bytes(operationIdentifier),
      "request_hash": .bytes(requestHash),
      "state": .text(state.rawValue),
      "transmission_count": .unsigned(UInt64(transmissionCount)),
      "automatic_retry_permitted": .boolean(automaticRetryPermitted),
    ])
    do {
      return try value.encoded()
    } catch {
      throw PairRecordError.invalidInput
    }
  }
}
