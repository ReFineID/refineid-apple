// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// An in-memory journal for both sides.
///
/// Every write is recorded so the harness can prove what reached storage and
/// in which order, which is how at-most-once is checked.
internal struct MemoryJournalStore: JournalStore, RequesterJournalStore {
  internal private(set) var proxyWrites: [ProxyJournalRecord] = []

  internal private(set) var requesterWrites: [RequesterJournalRecord] = []

  internal private(set) var retainedResults: [OperationResultMessage] = []

  internal var failNextWrite = false

  /// How many times a card command was durably accounted for.
  ///
  /// The transmission is the single write that enters `executing`. Later
  /// records still carry the count, so counting those would report the one
  /// transmission several times over.
  internal var transmissionsRecorded: Int {
    proxyWrites.filter { record in
      record.state == .executing && record.transmissionCount == TransmissionCount.single
    }.count
  }

  internal mutating func persist(_ record: ProxyJournalRecord) throws {
    try failIfRequested()
    proxyWrites.append(record)
  }

  internal mutating func persistResult(
    _ record: ProxyJournalRecord, result: OperationResultMessage
  ) throws {
    try failIfRequested()
    proxyWrites.append(record)
    retainedResults.append(result)
  }

  internal mutating func retainUncertainResult(_ record: ProxyJournalRecord) throws {
    try failIfRequested()
    proxyWrites.append(record)
  }

  internal mutating func acknowledgeResult(_ record: ProxyJournalRecord) throws {
    try failIfRequested()
    proxyWrites.append(record)
  }

  internal mutating func persist(_ record: RequesterJournalRecord) throws {
    try failIfRequested()
    requesterWrites.append(record)
  }

  private mutating func failIfRequested() throws {
    guard failNextWrite else { return }
    failNextWrite = false
    throw JournalError.persistence
  }
}
