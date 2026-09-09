// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import UIKit

  /// Lifts the screen while a code is being scanned, and puts it back.
  ///
  /// A camera reads dark modules against a light field, and a dimmed screen
  /// narrows that difference until the code stops resolving. The screen is
  /// the light source here, so it is turned up for as long as the code is
  /// shown and returned to whatever the holder had afterwards.
  @MainActor
  internal enum ScreenBrightness {
    /// The screen whose level was raised, and what to put back.
    private static var previous: (screen: UIScreen, brightness: CGFloat)?

    /// Bright enough to read in a lit room without being unpleasant.
    private static let scanningLevel: CGFloat = 1.0

    /// The foreground scene's screen, if one is connected.
    private static var activeScreen: UIScreen? {
      let scenes = UIApplication.shared.connectedScenes.compactMap { scene in
        scene as? UIWindowScene
      }
      return scenes.first { $0.activationState == .foregroundActive }?.screen
        ?? scenes.first?.screen
    }

    /// Raises the screen and remembers what to put back.
    internal static func raiseForScanning() {
      guard previous == nil, let screen = activeScreen else { return }
      previous = (screen, screen.brightness)
      screen.brightness = scanningLevel
    }

    /// Returns the screen to the level the holder chose.
    internal static func restore() {
      guard let previous else { return }
      previous.screen.brightness = previous.brightness
      Self.previous = nil
    }
  }

#endif
