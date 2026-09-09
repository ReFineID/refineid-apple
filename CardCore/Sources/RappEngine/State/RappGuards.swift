// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The set of guards an endpoint currently satisfies.
internal struct RappGuards: Sendable, Equatable {
  /// Every guard holds.
  ///
  /// Conformance checks drive rules with this so a rule is exercised on its
  /// transition, not on its guard.
  internal static let allSatisfied = Self(satisfied: Set(RappGuard.allCases))

  /// No guard holds.
  internal static let noneSatisfied = Self(satisfied: [])

  private var satisfied: Set<RappGuard>

  internal init(satisfied: Set<RappGuard>) {
    self.satisfied = satisfied
  }

  internal func isSatisfied(_ condition: RappGuard) -> Bool {
    satisfied.contains(condition)
  }

  internal mutating func set(_ condition: RappGuard, _ holds: Bool) {
    if holds {
      satisfied.insert(condition)
    } else {
      satisfied.remove(condition)
    }
  }

  /// A copy with one guard changed, for driving a single negative case.
  internal func setting(_ condition: RappGuard, _ holds: Bool) -> Self {
    var copy = self
    copy.set(condition, holds)
    return copy
  }
}
