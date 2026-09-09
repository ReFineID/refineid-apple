// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// PIN2, held for a few seconds so a batch is one prompt.
///
/// The card verifies PIN2 immediately before every qualified signature
/// and that cannot be changed. What this decides is where the value
/// comes from each time: from the holder, or from the entry the holder
/// just made. A batch of documents therefore costs one prompt, and a
/// prompt a person actually reads is worth more than twelve they
/// answer by reflex.
///
/// The window is deliberately short. It is measured from the entry, not
/// extended by use, so a batch that runs long asks again rather than
/// stretching one authorization indefinitely.
///
/// What it never does: reach disk, reach a log, outlive the session
/// that holds it, or satisfy anything but a qualified signature. PIN1
/// has its own path and the two are never interchangeable.
public struct Pin2Window {
  /// How long an entry stays usable.
  ///
  /// Long enough for a batch of documents, short enough that a card
  /// left in a reader is not a signing service for the rest of the
  /// afternoon.
  public static let lifetime: TimeInterval = 60

  private var value: String?
  private var enteredAt: Date?

  /// A window with nothing in it.
  public init() {
    // Both fields start empty; nothing is held until an entry is made.
  }

  /// Records an entry, starting the window.
  public mutating func hold(_ pin: String) {
    guard !pin.isEmpty else {
      forget()
      return
    }
    value = pin
    enteredAt = Date()
  }

  /// The entry, if one was made and the window has not closed.
  ///
  /// Reading does not extend it: the window belongs to the entry.
  public mutating func current(now: Date = Date()) -> String? {
    guard let value, let enteredAt else { return nil }
    guard now.timeIntervalSince(enteredAt) < Self.lifetime else {
      forget()
      return nil
    }
    return value
  }

  /// Drops the entry.
  ///
  /// On a refusal, on a card leaving, on anything unexpected. Cheap to
  /// call, and the safe thing to do when in doubt.
  public mutating func forget() {
    value = nil
    enteredAt = nil
  }
}
