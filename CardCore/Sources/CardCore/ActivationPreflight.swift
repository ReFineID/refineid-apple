// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The side-effect-free check before activation (FINEID S4-1 §4.6).
public enum ActivationPreflight {
  /// Evaluates one PIN's readiness from counter-safe probes alone.
  ///
  /// Judged per PIN, because §4.6 sets each PIN's changed flag
  /// individually and an interrupted activation leaves one PIN set
  /// and the other in its factory state. A card is awaiting
  /// activation while any of its PINs is; the set one is skipped, not
  /// set again - under §4.6.2 the activation PIN stops being a PIN's
  /// current value the moment that PIN is changed, and presenting it
  /// again would spend a retry on a value that cannot match.
  ///
  /// Under the activation-code scheme (§4.6.1) both PINs ship blocked
  /// and the factory state answers the probe with nothing usable, so a
  /// live counter reading - remaining attempts, verified, or locked -
  /// means the slot has been written to since manufacture. Locked
  /// counts because it is activated-then-exhausted, not factory-fresh.
  ///
  /// An invalidated slot does NOT count. That is a state a card can be
  /// in before it was ever activated, and reading it as prior use
  /// would withhold activation from exactly the card that needs it.
  ///
  /// Under the preset-PIN scheme (§4.6.2) the PIN ships set to the
  /// activation PIN, so a healthy counter is the expected fresh state
  /// and proves nothing. The changed-since-manufacture record is the
  /// authoritative signal; only `changed` blocks the flow, an
  /// unreadable record does not.
  public static func evaluate(
    scheme: ActivationScheme,
    probe: RetryProbeOutcome?,
    changeRecord: PinChangeRecord
  ) -> ActivationReadiness {
    switch scheme {
    case .presetActivationPin:
      return changeRecord == .changed ? .alreadyActivated : .ready

    case .activationCodeIsPuk:
      switch probe {
      case .remaining, .verified, .locked:
        return .alreadyActivated

      case .invalidated, .noInformation, .other, .none:
        return .ready
      }
    }
  }
}
