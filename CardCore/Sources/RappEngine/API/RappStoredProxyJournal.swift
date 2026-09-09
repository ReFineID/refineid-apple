// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One stored proxy operation record and the result it still retains.
public struct RappStoredProxyJournal: Equatable, Sendable {
  /// The encoded operation record.
  public var record: Data
  /// Present while a completed result has been retained but not acknowledged.
  public var retainedResult: Data?

  /// Describes one stored record and any result it retains.
  public init(record: Data, retainedResult: Data?) {
    self.record = record
    self.retainedResult = retainedResult
  }
}
