// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// An in-memory journal store that records every write in order.
internal struct OperationJournalStore: JournalStore {
  internal private(set) var writes: [ProxyJournalRecord] = []

  internal private(set) var retained: [Data: OperationResultMessage] = [:]

  internal private(set) var acknowledged = 0

  internal private(set) var uncertain = 0

  internal var failNextWrite = false

  /// Total physical transmissions the durable trail accounts for.
  internal var recordedTransmissions: Int {
    writes.contains { record in record.transmissionCount == TransmissionCount.single } ? 1 : 0
  }

  internal mutating func persist(_ record: ProxyJournalRecord) throws {
    if failNextWrite { throw JournalError.persistence }
    writes.append(record)
  }

  internal mutating func persistResult(
    _ record: ProxyJournalRecord, result: OperationResultMessage
  ) throws {
    if failNextWrite { throw JournalError.persistence }
    writes.append(record)
    retained[record.operationIdentifier] = result
  }

  internal mutating func retainUncertainResult(_ record: ProxyJournalRecord) {
    writes.append(record)
    uncertain += 1
  }

  internal mutating func acknowledgeResult(_ record: ProxyJournalRecord) {
    writes.append(record)
    retained.removeValue(forKey: record.operationIdentifier)
    acknowledged += 1
  }
}
