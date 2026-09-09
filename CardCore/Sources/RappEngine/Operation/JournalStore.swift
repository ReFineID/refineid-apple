// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Where a durable operation record may be written.
///
/// Each call is one atomic storage transaction. A record reaches storage
/// before the card is touched, never after.
internal protocol JournalStore {
  /// Writes the complete record.
  mutating func persist(_ record: ProxyJournalRecord) throws

  /// Writes the record together with the result it retains, before that
  /// result is released to the transport.
  mutating func persistResult(
    _ record: ProxyJournalRecord,
    result: OperationResultMessage
  ) throws

  /// Marks delivery uncertain while keeping the retained result.
  mutating func retainUncertainResult(_ record: ProxyJournalRecord) throws

  /// Marks acknowledgement and erases the retained result.
  mutating func acknowledgeResult(_ record: ProxyJournalRecord) throws
}
