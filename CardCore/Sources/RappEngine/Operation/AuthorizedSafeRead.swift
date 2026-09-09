// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A registered read that touches no credential retry budget.
internal struct AuthorizedSafeRead: Equatable {
  internal let operation: CardOperation
}
