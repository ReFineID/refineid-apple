// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What receiving a pong proved.
internal enum PongDisposition: Equatable {
  /// The exact outstanding challenge came back; liveness is proven.
  case accepted
  /// Nothing outstanding matched. A stale-reference race, discarded, and not
  /// liveness proof.
  case ignoredUnmatched
}
