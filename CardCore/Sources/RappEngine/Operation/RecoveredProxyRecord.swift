// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One journal entry recovered after a restart.
internal struct RecoveredProxyRecord: Equatable {
  internal let record: ProxyJournalRecord
  /// Present only while a completed result awaits acknowledgement, or after
  /// delivery became uncertain.
  internal let retainedResult: OperationResultMessage?
}
