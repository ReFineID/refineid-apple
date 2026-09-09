// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What a local cancellation means, decided by the commit boundary.
internal enum RequesterCancelAction: Equatable {
  /// The commit had passed, so the card may already have acted. The
  /// cancellation travels but the operation keeps its own course.
  case advisory(TypedMessage)
  /// Nothing was committed, so the cancellation is terminal.
  case terminal(TypedMessage)
}
