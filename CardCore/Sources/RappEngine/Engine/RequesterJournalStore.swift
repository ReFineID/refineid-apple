// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Where a requester's durable operation records are written.
///
/// Reaching a terminal state removes the record instead of persisting it.
/// Only interrupted records (ambiguous or delivery-uncertain) stay stored
/// for reconciliation.
internal protocol RequesterJournalStore {
  mutating func persist(_ record: RequesterJournalRecord) throws

  /// Deletes the stored record for one operation; absent is not an error.
  mutating func remove(operationIdentifier: Data) throws
}
