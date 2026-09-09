// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The result of a rule that fired: the next state and the ordered actions.
internal struct RappTransition<State: Equatable & Sendable>: Sendable, Equatable {
  internal let state: State
  internal let actions: [RappAction]
}
