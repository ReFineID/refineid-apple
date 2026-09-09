// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Sizes the specification fixes for journalled identifiers.
internal enum JournalSize {
  internal static let sessionIdentifier = 16
  internal static let operationIdentifier = 16
  internal static let requestHash = 32
}
