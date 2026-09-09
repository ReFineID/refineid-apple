// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

extension SessionState {
  /// The session rule that fires, or nil when none does.
  internal static func transition(
    from state: Self,
    on event: SessionEvent,
    role: EndpointRole,
    guards: RappGuards
  ) -> RappTransition<Self>? {
    guard case .fire(let transition) = outcome(from: state, on: event, role: role, guards: guards)
    else { return nil }
    return transition
  }

  /// The session rule that fires when every guard holds.
  internal static func transition(
    from state: Self,
    on event: SessionEvent,
    role: EndpointRole
  ) -> RappTransition<Self>? {
    transition(from: state, on: event, role: role, guards: .allSatisfied)
  }

  internal static func outcome(
    from state: Self,
    on event: SessionEvent,
    role: EndpointRole,
    guards: RappGuards
  ) -> RappTransitionOutcome<Self> {
    rappResolve(RappModelTables.session, from: state, on: event, role: role, guards: guards)
  }

  /// The outcome when every guard holds.
  internal static func outcome(
    from state: Self,
    on event: SessionEvent,
    role: EndpointRole
  ) -> RappTransitionOutcome<Self> {
    outcome(from: state, on: event, role: role, guards: .allSatisfied)
  }
}
