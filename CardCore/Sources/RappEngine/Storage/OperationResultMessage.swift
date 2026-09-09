// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Profile-defined answer to one operation, as carried on the wire and
/// retained until the requester acknowledges it.
internal struct OperationResultMessage: Equatable {
  internal var operationIdentifier: Data
  internal var requestHash: Data
  internal var status: ResultStatus
  internal var error: ResultError?
  internal var result: CardOperationResult?

  /// The body fields this result puts on the wire.
  ///
  /// The sealing path needs the fields rather than their encoding, so the two
  /// share one definition and cannot describe the same result differently.
  internal var wireBody: [String: WireValue] {
    var body: [String: WireValue] = [
      "operation_id": .bytes(operationIdentifier),
      "request_hash": .bytes(requestHash),
      "status": .text(status.rawValue),
      "body": .map(result.map(wireResultBody) ?? [:]),
    ]
    if let error {
      body["error"] = .text(error.rawValue)
    }
    return body
  }

  /// A completed result carries an output and no error; every other status
  /// carries a matching error and no output.
  private var isConsistent: Bool {
    switch (status, error, result) {
    case (.completed, .none, .some):
      true

    case (_, .some, .none):
      true

    default:
      false
    }
  }

  internal static func decode(_ bytes: Data) throws -> Self {
    var map = try decodedMap(bytes)
    let decodedOperationIdentifier = try takeBytes(&map, "operation_id")
    let decodedRequestHash = try takeBytes(&map, "request_hash")
    guard decodedOperationIdentifier.count == JournalSize.operationIdentifier,
      decodedRequestHash.count == JournalSize.requestHash
    else { throw PairRecordError.invalidInput }
    guard let decodedStatus = ResultStatus(rawValue: try takeText(&map, "status")) else {
      throw PairRecordError.invalidInput
    }
    let decodedError: ResultError?
    switch map.removeValue(forKey: "error") {
    case .none:
      decodedError = nil

    case .some(.text(let name)):
      guard let parsed = ResultError(rawValue: name) else { throw PairRecordError.invalidInput }
      decodedError = parsed

    case .some:
      throw PairRecordError.invalidInput
    }
    let resultBody = try takeMap(&map, "body")
    guard map.isEmpty else { throw PairRecordError.invalidInput }
    let decodedResult: CardOperationResult?
    if decodedStatus == .completed {
      decodedResult = try wireResultFrom(resultBody)
    } else {
      guard resultBody.isEmpty else { throw PairRecordError.invalidInput }
      decodedResult = nil
    }
    let message = Self(
      operationIdentifier: decodedOperationIdentifier,
      requestHash: decodedRequestHash,
      status: decodedStatus,
      error: decodedError,
      result: decodedResult
    )
    guard message.isConsistent else { throw PairRecordError.invalidInput }
    return message
  }

  internal func encoded() throws -> Data {
    do {
      return try WireValue.map(wireBody).encoded()
    } catch {
      throw PairRecordError.invalidInput
    }
  }
}
