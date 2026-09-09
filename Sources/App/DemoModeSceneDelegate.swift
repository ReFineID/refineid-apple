// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import UIKit

  /// Catches the Home Screen action taken while the app was running.
  ///
  /// Installed by ``DemoModeAppDelegate`` as the scene's delegate class.
  /// The window is SwiftUI's throughout: this answers one optional
  /// requirement and leaves every other to the default scene delegate the
  /// generated manifest names.
  @MainActor
  internal final class DemoModeSceneDelegate: NSObject, UIWindowSceneDelegate {
    internal func windowScene(
      _: UIWindowScene,
      performActionFor shortcutItem: UIApplicationShortcutItem,
      // The handler is called before this returns and never stored, but
      // the escaping attribute is what makes the signature match the
      // optional requirement, and a signature that does not match is a
      // method the system never calls.
      // swiftlint:disable:next unneeded_escaping
      completionHandler: @escaping (Bool) -> Void
    ) {
      completionHandler(DemoModeShortcut.perform(shortcutItem))
    }
  }

#endif
