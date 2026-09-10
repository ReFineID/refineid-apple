// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

extension CardActivationSection {
  /// The keyboard path through the section.
  internal enum Field {
    case entry
    case pin1
    case pin1Repeat
    case pin2
    case pin2Repeat
  }

  /// Whether the form asks for PIN 1 because the card still waits for it.
  internal var asksPin1: Bool {
    model.activationNeeds.pin1
  }

  /// Whether the form asks for PIN 2 because the card still waits for it.
  internal var asksPin2: Bool {
    model.activationNeeds.pin2
  }

  /// The fields on screen, in the order Return walks them.
  internal var shownFields: [Field] {
    [.entry]
      + (asksPin1 ? [.pin1, .pin1Repeat] : [])
      + (asksPin2 ? [.pin2, .pin2Repeat] : [])
  }
}
