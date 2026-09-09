// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Bounds the human-readable context an operation may carry.
internal enum OperationLimit {
  /// Longest display name or origin an authorizer is asked to render.
  internal static let displayContextBytes = 512
}
