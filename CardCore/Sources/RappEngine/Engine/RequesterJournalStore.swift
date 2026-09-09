// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Where a requester's durable operation records are written.
internal protocol RequesterJournalStore {
  mutating func persist(_ record: RequesterJournalRecord) throws
}
