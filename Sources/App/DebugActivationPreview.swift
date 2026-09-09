// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG && os(macOS)

  import Foundation

  /// Development-only forcing of the activation takeover.
  ///
  /// The takeover appears only for a card in its factory state, which
  /// a developer machine rarely has one of: a card activates once in
  /// its life. This shows the takeover without a card so the screen
  /// can be seen and audited; the card operations behind the button
  /// still require the real thing. Release builds contain none of
  /// this type or its argument.
  internal enum DebugActivationPreview {
    /// A normal-UI launch argument; it is deliberately not a debug
    /// launch mode.
    internal static let launchArgument = "--preview-activation"

    /// Whether this process was explicitly launched to show the
    /// takeover.
    internal static func isEnabled() -> Bool {
      Self.isEnabled(arguments: ProcessInfo.processInfo.arguments)
    }

    /// Whether the supplied process arguments explicitly force it.
    internal static func isEnabled(arguments: [String]) -> Bool {
      arguments.contains(Self.launchArgument)
        && !DebugLaunchMode.allCases.contains { mode in
          arguments.contains(mode.rawValue)
        }
    }
  }

#endif
