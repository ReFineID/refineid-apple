// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension CardCredentialStore {
  /// The platform half of the above: iOS shares a keychain access group
  /// with its extensions and needs no second copy of the number, so it
  /// does not make one.
  @discardableResult
  internal static func publishToDriver(digits: String) -> Bool {
    #if os(macOS)
      return OfferedAccessNumber.publish(digits: digits)
    #else
      return false
    #endif
  }

  /// Item coordinates shared by every operation.
  ///
  /// `ThisDeviceOnly` keeps these out of backups and off other devices;
  /// `synchronizable` false keeps them out of iCloud. Both are required
  /// -- neither implies the other.
  internal static func query(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      // iOS only. On macOS the data-protection keychain requires a
      // keychain-access-group entitlement, and asking for one there
      // fails signing on a development profile -- every store call then
      // answers errSecMissingEntitlement and the app cannot keep a card
      // access number at all. The file keychain needs no entitlement and
      // is protected by the same login keychain the rest of the system
      // uses.
      kSecUseDataProtectionKeychain as String: KeychainPlatform.usesDataProtection,
      kSecAttrSynchronizable as String: false,
    ]
  }

  /// Whether an item is present, without authenticating.
  ///
  /// The lookup explicitly skips any interface. A protected item then
  /// answers `errSecInteractionNotAllowed`, which is itself proof that
  /// it exists -- so both that and success count as present, and neither
  /// prompts the holder just to draw a status row.
  internal static func exists(account: String) -> Bool {
    if TestCredentialEnvironment.isTestMode {
      return TestCredentialEnvironment.credentialExists(account: account)
    }
    var query = self.query(account: account)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
    let status = SecItemCopyMatching(query as CFDictionary, nil)
    return status == errSecSuccess || status == errSecInteractionNotAllowed
  }

  /// Reads a value.
  ///
  /// Nothing in the app calls this to display a value -- it exists so
  /// card setup can use what was entered earlier.
  internal static func read(account: String) -> String? {
    if TestCredentialEnvironment.isTestMode {
      return TestCredentialEnvironment.readCredential(account: account)
    }
    var query = self.query(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// Writes a value.
  ///
  /// Returns the keychain's own status rather than a bare false, because
  /// a refusal here is not the holder's fault, and telling them their PIN
  /// is invalid when the store merely could not replace an item sends
  /// them looking in the wrong place.
  internal static func write(_ digits: String, account: String) -> OSStatus {
    guard let data = digits.data(using: .utf8) else { return errSecParam }
    if TestCredentialEnvironment.isTestMode {
      TestCredentialEnvironment.writeCredential(digits, account: account)
      return errSecSuccess
    }
    let coordinates = query(account: account)
    let replacement = [kSecValueData as String: data]
    let updated = SecItemUpdate(
      coordinates as CFDictionary,
      replacement as CFDictionary)
    if updated == errSecSuccess { return updated }
    guard updated == errSecItemNotFound else { return updated }

    var insertion = coordinates
    insertion[kSecValueData as String] = data
    insertion[kSecAttrAccessible as String] =
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(insertion as CFDictionary, nil)
  }

  /// Removes an item.
  ///
  /// Deletion does NOT skip the authentication interface. Skipping it
  /// makes a biometrically protected item answer
  /// `errSecInteractionNotAllowed` and survive, after which the add that
  /// follows fails as a duplicate and a perfectly good PIN looks
  /// rejected. Measured: this is exactly why storing PIN1 appeared to do
  /// nothing while storing the ungated access number worked.
  internal static func delete(account: String) {
    if TestCredentialEnvironment.isTestMode {
      TestCredentialEnvironment.deleteCredential(account: account)
      return
    }
    SecItemDelete(query(account: account) as CFDictionary)
  }
}
