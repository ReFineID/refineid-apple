// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// How a cancellation lands relative to the durable commit.
internal enum ProxyCancelOutcome: Equatable {
  /// The commit had passed; the cancellation is recorded and the operation
  /// continues to its own terminal state.
  case advisory
  /// No transmission had begun, so the operation is cancelled.
  case cancelled
}
