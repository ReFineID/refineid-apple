// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Counts how many times the card was actually reached.
internal actor SignRelayPerformanceCounter {
  internal private(set) var count = 0

  /// Records one performance.
  internal func increment() {
    count += 1
  }
}
