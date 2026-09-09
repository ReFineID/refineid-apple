// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// What one completed exchange left behind: both engines and the store, so a
/// caller can inspect the durable trail the operation produced.
internal struct HappyPath {
  internal var proxy: ProxyOperationEngine
  internal var requester: RequesterOperationEngine
  internal var store: MemoryJournalStore
}
