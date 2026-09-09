// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import SwiftUI

  /// Placing focus in the first field of a window that has just opened.
  ///
  /// A card window is a form and nothing else: the holder opened it to
  /// type a PIN. If focus is not in the first field when it appears,
  /// the keyboard does nothing until a pointer has been used, which
  /// leaves the window operable only by someone who can use one.
  ///
  /// Assigning focus as the form appears does not work, and neither
  /// does declaring it with `defaultFocus`. Measured on macOS 26: with
  /// either, a PIN typed a second and a half after the window opened
  /// went nowhere at all, and the form could not be completed without
  /// clicking a field first. Waiting for the window to finish becoming
  /// key, then assigning, does work.
  internal enum InitialFieldFocus {
    /// How long to wait before assigning focus.
    ///
    /// Long enough for the window to become key, short enough that the
    /// first keystroke of someone already typing is not lost.
    private static let delayMilliseconds = 100

    /// Waits for the window to settle before focus is placed in it.
    internal static func settle() async {
      try? await Task.sleep(for: .milliseconds(delayMilliseconds))
    }
  }

#endif
