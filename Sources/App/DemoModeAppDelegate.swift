// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import UIKit

  /// Catches the Home Screen action that launched the app.
  ///
  /// The action is in the connection options, and it is read before the
  /// first screen is built, so a launch that asked for a demonstration is
  /// already one by the time anything is drawn.
  ///
  /// The configuration is built with a nil name, which takes the default
  /// scene configuration from the generated manifest. Only its delegate
  /// class is replaced, with ``DemoModeSceneDelegate``, which answers the
  /// action taken while the app is already running and nothing else.
  ///
  /// The app has no other use for an application delegate.
  @MainActor
  internal final class DemoModeAppDelegate: NSObject, UIApplicationDelegate {
    internal func application(
      _: UIApplication,
      configurationForConnecting session: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      DemoModeShortcut.perform(options.shortcutItem)
      let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
      configuration.delegateClass = DemoModeSceneDelegate.self
      return configuration
    }
  }

#endif
