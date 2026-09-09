// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// Hex of one message body, for comparing against the pinned corpus.
private func encodedHex(_ message: TypedMessage) throws -> String {
  guard let bytes = try message.encodedBody() else { return "" }
  return bytes.map { String(format: "%02x", $0) }.joined()
}

/// The bodies the engines must be able to SEND, encoded through
/// TypedMessage rather than assembled by hand in a test.
@Suite("RAPP send bodies against the pinned corpus")
internal struct EngineSendBodyTests {
  @Test("Every sent body matches the pinned bytes")
  internal func sendBodiesMatchTheCorpus() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    var pinned: [String: String] = [:]
    for entry in corpus.vectors {
      pinned[entry.name] = entry.bodyHex
    }
    let statusIdentifier = Data(repeating: 0x44, count: 16)
    let errorIdentifier = Data(repeating: 0x66, count: 16)
    let statusHash = Data(repeating: 0x55, count: 32)
    // Cancel echoes the ordinary operation reference, not the status one.
    let cancelReference = OperationReference(
      operationIdentifier: Data(repeating: 0x22, count: 16),
      requestHash: Data(repeating: 0x33, count: 32))

    let cases: [(String, TypedMessage)] = [
      (
        "cancel-with-reason",
        .operationCancel(
          CancelMessage(reference: cancelReference, reason: EngineFixture.cancelReason))
      ),
      (
        "cancel-without-reason",
        .operationCancel(CancelMessage(reference: cancelReference, reason: nil))
      ),
      ("status-request", .operationStatusRequest(operationIdentifier: statusIdentifier)),
      (
        "status-known-completed",
        .operationStatus(
          StatusReport(
            operationIdentifier: statusIdentifier, known: true, state: .completed,
            requestHash: statusHash))
      ),
      (
        "status-unknown",
        .operationStatus(StatusReport(operationIdentifier: statusIdentifier, known: false))
      ),
      ("error-busy", .error(.busy)),
      (
        "error-unknown-operation-with-id",
        .error(.unknownOperation(operationIdentifier: errorIdentifier))
      ),
      ("error-unknown-operation-bare", .error(.unknownOperation(operationIdentifier: nil))),
    ]
    for (name, message) in cases {
      let produced = try encodedHex(message)
      EngineReport.check(
        !produced.isEmpty && produced == pinned[name], "\(name) encodes to the pinned bytes")
    }
    // The trap: the wire form omits absent fields, so an unknown status is a
    // two-key map, never the journal's four-key form with explicit nulls.
    let unknownBody = StatusReport(operationIdentifier: statusIdentifier, known: false).wireBody
    EngineReport.check(
      unknownBody.count == 2, "an unknown status omits state and request_hash")
  }
}
