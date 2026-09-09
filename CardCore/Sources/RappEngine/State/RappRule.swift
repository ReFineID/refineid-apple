// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// One rule of the formal model.
///
/// A rule listing several `from` states is shorthand for one rule per listed
/// state, so the array is kept rather than expanded and every check reads it
/// the same way the model does. The document names the destination field
/// `to`; the Swift property is `destination`.
internal struct RappRule<State: Equatable & Sendable, Event: Equatable & Sendable>: Sendable {
  internal let from: [State]
  internal let event: Event
  internal let role: RuleRole
  internal let condition: RappGuard?
  internal let destination: State
  internal let actions: [RappAction]

  internal init(
    from: [State],
    event: Event,
    role: RuleRole,
    condition: RappGuard?,
    destination: State,
    actions: [RappAction]
  ) {
    self.from = from
    self.event = event
    self.role = role
    self.condition = condition
    self.destination = destination
    self.actions = actions
  }

  /// A rule no guard governs.
  internal init(
    from: [State],
    event: Event,
    role: RuleRole,
    destination: State,
    actions: [RappAction]
  ) {
    self.init(
      from: from, event: event, role: role, condition: nil, destination: destination,
      actions: actions)
  }

  internal init(
    from: State,
    event: Event,
    role: RuleRole,
    condition: RappGuard?,
    destination: State,
    actions: [RappAction]
  ) {
    self.init(
      from: [from], event: event, role: role, condition: condition, destination: destination,
      actions: actions)
  }

  /// A rule for one state that no guard governs.
  internal init(
    from: State,
    event: Event,
    role: RuleRole,
    destination: State,
    actions: [RappAction]
  ) {
    self.init(
      from: [from], event: event, role: role, condition: nil, destination: destination,
      actions: actions)
  }

  /// Whether this rule governs the given state, event, and endpoint.
  internal func governs(state: State, event candidate: Event, role endpoint: EndpointRole) -> Bool {
    from.contains(state) && self.event == candidate && role.includes(endpoint)
  }
}

/// Resolves an event against a rule table.
///
/// There are no wildcard rules, so an event with no governing rule returns
/// `noRule` and belongs to an unexpected-input policy class.
internal func rappResolve<State, Event>(
  _ rules: [RappRule<State, Event>],
  from state: State,
  on event: Event,
  role: EndpointRole,
  guards: RappGuards
) -> RappTransitionOutcome<State> {
  guard let rule = rules.first(where: { $0.governs(state: state, event: event, role: role) })
  else {
    return .noRule
  }
  if let condition = rule.condition, !guards.isSatisfied(condition) {
    return .guardFailed(condition)
  }
  return .fire(RappTransition(state: rule.destination, actions: rule.actions))
}
