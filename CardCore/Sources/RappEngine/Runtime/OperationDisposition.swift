// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// What becomes of the active operation.
internal enum OperationDisposition: Equatable, Sendable {
  /// Report an unknown result and never transmit the command again.
  case ambiguousNeverRetry
  /// Fail without retrying.
  case fail
  /// Refuse before any card command was committed.
  case reject
  /// Consult the journal to separate a safe refusal from a committed command.
  case resolveFromJournal
}
