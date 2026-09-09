// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The hoops a card goes through while being set up.
///
/// Setup is several seconds of holding a card against a phone with
/// nothing visibly happening, which is exactly when a holder moves it.
/// Naming the steps lets the screen show which one is running and which
/// one broke, so a hold that fails half way is legible instead of being
/// a wall of text ending in failure.
///
/// The order is the order they happen in, which is why the cases are not
/// alphabetical: a step list sorted by name would misdescribe the thing
/// it exists to describe.
internal enum CardPrimingStep: Int, CaseIterable, Sendable {
  // These cases ARE the order the steps happen in, and the view that
  // draws them walks the cases. Sorting them by name would misdescribe
  // the one thing this type exists to describe.
  // swiftlint:disable sorted_enum_cases
  /// The card answered the phone's antenna.
  case found = 0

  /// PACE ran and the secure channel is open.
  case secureChannel = 1

  /// The certificate was read off the card.
  case certificate = 2

  /// The card details were written to this iPhone.
  case stored = 3

  /// The card was registered so Safari can ask for it.
  case registered = 4

  // swiftlint:enable sorted_enum_cases

  /// How this step is going.
  internal enum State: Sendable {
    /// Finished.
    case done

    /// Broke here.
    case failed

    /// Running now.
    case running

    /// Not reached yet.
    case waiting
  }

  /// What the holder is told this step is.
  internal var title: String {
    switch self {
    case .found:
      String(localized: "Card found")

    case .secureChannel:
      String(localized: "Secure channel")

    case .certificate:
      String(localized: "Certificate read")

    case .stored:
      String(localized: "Saved to this iPhone")

    case .registered:
      String(localized: "Ready for Safari")
    }
  }
}
