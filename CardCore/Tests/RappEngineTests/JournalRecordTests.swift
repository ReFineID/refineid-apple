// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

@Suite("RAPP operation journal storage format")
internal struct JournalRecordTests {
  /// Card transmissions the proxy fixture records.
  private static let recordedTransmissions: UInt8 = 1

  /// Remaining attempts the inspection fixture reports.
  private static let inspectionPin1Attempts: UInt8 = 5
  private static let inspectionPukAttempts: UInt8 = 3

  private func requesterRecord() -> RequesterJournalRecord {
    RequesterJournalRecord(
      pairIdentifier: filler(0x11, PairRecordSize.pairIdentifier),
      sessionIdentifier: filler(0x22, JournalSize.sessionIdentifier),
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      state: .committed,
      retainedResult: .identity(displayName: "Test Holder", personIdentifier: "010101-0101"),
      reconciliation: StatusReport(
        operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
        known: true,
        state: .completed,
        requestHash: filler(0x44, JournalSize.requestHash)))
  }

  private func proxyRecord() -> ProxyJournalRecord {
    ProxyJournalRecord(
      pairIdentifier: filler(0x11, PairRecordSize.pairIdentifier),
      sessionIdentifier: filler(0x22, JournalSize.sessionIdentifier),
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      state: .executing,
      transmissionCount: Self.recordedTransmissions,
      automaticRetryPermitted: false)
  }

  private func completedResult() -> OperationResultMessage {
    OperationResultMessage(
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      status: .completed,
      error: nil,
      result: .certificate(Data([0xde, 0xad, 0xbe, 0xef])))
  }

  private func golden(_ text: String) throws -> Data {
    try Data(hex: text.filter { !$0.isWhitespace })
  }

  private func mutatedProxy(_ field: String, _ value: WireValue) throws -> Data {
    guard case .map(var map) = try decodeDeterministicCbor(try proxyRecord().encoded()) else {
      throw PairRecordError.invalidInput
    }
    map[field] = value
    return try WireValue.map(map).encoded()
  }

  @Test("The requester record is byte-identical to the reference implementation")
  internal func requesterRecordMatchesReference() throws {
    #expect(try requesterRecord().encoded() == (try golden(expectedRequesterJournalHex)))
  }

  @Test("The requester record round-trips")
  internal func requesterRecordRoundTrips() throws {
    let record = requesterRecord()
    #expect(try RequesterJournalRecord.decode(try record.encoded()) == record)
  }

  @Test("The proxy record is byte-identical to the reference implementation")
  internal func proxyRecordMatchesReference() throws {
    #expect(try proxyRecord().encoded() == (try golden(expectedProxyJournalHex)))
  }

  @Test("The proxy record round-trips")
  internal func proxyRecordRoundTrips() throws {
    let record = proxyRecord()
    #expect(try ProxyJournalRecord.decode(try record.encoded()) == record)
  }

  @Test("The operation result is byte-identical to the reference implementation")
  internal func operationResultMatchesReference() throws {
    #expect(try completedResult().encoded() == (try golden(expectedOperationResultHex)))
  }

  @Test("The operation result round-trips")
  internal func operationResultRoundTrips() throws {
    let result = completedResult()
    #expect(try OperationResultMessage.decode(try result.encoded()) == result)
  }

  @Test("A denied result round-trips carrying no output")
  internal func deniedResultRoundTrips() throws {
    let denied = OperationResultMessage(
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      status: .denied,
      error: .userDenied,
      result: nil)
    #expect(try OperationResultMessage.decode(try denied.encoded()) == denied)
  }

  @Test("A retained inspection with absent counters round-trips")
  internal func retainedInspectionRoundTrips() throws {
    let inspection = RequesterJournalRecord(
      pairIdentifier: filler(0x11, PairRecordSize.pairIdentifier),
      sessionIdentifier: filler(0x22, JournalSize.sessionIdentifier),
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      state: .completed,
      retainedResult: .inspection(
        CardInspection(
          pin1Factory: true, pin2Factory: false,
          pin1Attempts: Self.inspectionPin1Attempts, pin2Attempts: nil,
          pukAttempts: Self.inspectionPukAttempts)),
      reconciliation: nil)
    #expect(try RequesterJournalRecord.decode(try inspection.encoded()) == inspection)
  }

  @Test("A wrong format version is rejected")
  internal func wrongFormatVersionIsRejected() throws {
    #expect(throws: (any Error).self) {
      _ = try ProxyJournalRecord.decode(try mutatedProxy("format_version", .unsigned(2)))
    }
  }

  @Test("An unknown operation state is rejected")
  internal func unknownStateIsRejected() throws {
    #expect(throws: (any Error).self) {
      _ = try ProxyJournalRecord.decode(try mutatedProxy("state", .text("unheard_of")))
    }
  }

  @Test("A completed result carrying no output is rejected")
  internal func completedResultWithoutOutputIsRejected() throws {
    let inconsistent = OperationResultMessage(
      operationIdentifier: filler(0x33, JournalSize.operationIdentifier),
      requestHash: filler(0x44, JournalSize.requestHash),
      status: .completed, error: nil, result: nil)
    #expect(throws: (any Error).self) {
      _ = try OperationResultMessage.decode(try inconsistent.encoded())
    }
  }
}
