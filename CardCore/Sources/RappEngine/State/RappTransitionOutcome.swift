// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// What an endpoint does with an event in its current state.
///
/// The three cases are distinct in the model: a fired rule changes state, a
/// failed guard leaves state unchanged and answers within the failure
/// taxonomy, and an absent rule is handled by an unexpected-input policy
/// class. Collapsing the last two would lose that distinction.
internal enum RappTransitionOutcome<State: Equatable & Sendable>: Sendable, Equatable {
  case fire(RappTransition<State>)
  case guardFailed(RappGuard)
  case noRule
}
