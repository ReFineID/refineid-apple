// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Records presence callbacks in the order they arrived.
internal actor StreamRelayPresenceBox {
  private var values: [Bool] = []

  /// Whether a find was followed by a loss.
  internal var sawTrueThenFalse: Bool {
    guard let firstTrue = values.firstIndex(of: true) else { return false }
    return values[firstTrue...].contains(false)
  }

  /// Records one presence value.
  internal func add(_ present: Bool) {
    values.append(present)
  }

  /// Whether `present` has been reported at least once.
  internal func contains(_ present: Bool) -> Bool {
    values.contains(present)
  }
}
