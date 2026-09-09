// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Reads and writes the holder's transport preference where both the app
/// and the token extension can see it.
///
/// The two are separate processes with separate sandboxes, so a plain
/// `UserDefaults.standard` would give each its own private answer: the
/// holder would switch a transport off in the app and the extension would
/// keep serving it. A keychain item in the shared access group is the one
/// store both sides genuinely share.
///
/// Reads fail open to `readerOnly`, never closed. A missing or
/// unreadable preference must still leave a Mac able to publish a token
/// from its reader.
public enum CardTransportStore {
  /// Decoding shape, kept private so the domain type never gains a path
  /// around its validating initializer.
  private struct StoredSelection: Codable {
    var enabled: [String]
  }

  /// Keychain service for the preference item.
  private static let service = "fi.refineid.transport"

  /// Single well-known account: there is one preference per device.
  private static let account = "selection"

  /// The stored preference, or every transport this build knows when
  /// absent or unreadable.
  ///
  /// A holder who has chosen nothing should get the phone's own antenna,
  /// which needs no hardware; callers clamp this to what the platform
  /// actually has, so a Mac still ends up reader-only.
  public static func load() -> CardTransportSelection {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data,
      let stored = try? JSONDecoder().decode(StoredSelection.self, from: data)
    else {
      return .all
    }
    let transports = Set(stored.enabled.compactMap(CardTransport.init(rawValue:)))
    return CardTransportSelection(enabled: transports) ?? .all
  }

  /// Replaces the stored preference.
  ///
  /// Returns false when the keychain refuses the write, so a caller can
  /// tell the holder it did not stick.
  @discardableResult
  public static func save(_ selection: CardTransportSelection) -> Bool {
    let stored = StoredSelection(enabled: selection.enabled.map(\.rawValue).sorted())
    guard let data = try? JSONEncoder().encode(stored) else { return false }
    let query = baseQuery()
    let attributes: [String: Any] = [kSecValueData as String: data]
    let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updated == errSecSuccess { return true }
    guard updated == errSecItemNotFound else { return false }
    var insert = baseQuery()
    insert[kSecValueData as String] = data
    return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
  }

  /// Item coordinates shared by every operation.
  ///
  /// `kSecUseDataProtectionKeychain` must be set identically on both
  /// sides or the app and the extension address different keychains and
  /// silently never see each other's writes. The accessibility is
  /// after-first-unlock rather than when-unlocked because the extension
  /// runs backgrounded when the system asks it for a signature.
  private static func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecUseDataProtectionKeychain as String: KeychainPlatform.usesDataProtection,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecAttrSynchronizable as String: false,
    ]
  }
}
