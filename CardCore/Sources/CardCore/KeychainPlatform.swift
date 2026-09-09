// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Which keychain the card stores use on this platform.
///
/// Both iOS and macOS use the data-protection keychain backed by
/// the shared App Group (`group.fi.refineid.RefineID`), ensuring items are
/// device-only, non-syncable, shared securely between the app and its token
/// extensions, and free from per-build login keychain authorization dialogs.
internal enum KeychainPlatform {
  /// Whether `kSecUseDataProtectionKeychain` may be requested.
  internal static var usesDataProtection: Bool {
    #if os(iOS)
      true
    #else
      false
    #endif
  }
}
