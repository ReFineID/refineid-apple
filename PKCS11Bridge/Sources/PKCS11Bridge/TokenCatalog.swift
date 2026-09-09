// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import CryptoTokenKit
import Foundation
import LocalAuthentication
import Security

/// Builds the registry's token and object snapshot from the keychain.
///
/// Identities published by CryptoTokenKit token extensions surface as
/// keychain items carrying a token ID; each yields a certificate, a
/// public-key, and a private-key object sharing one CKA_ID (the public
/// key hash the system stores as the application label). EC and RSA
/// identities are both published.
internal enum TokenCatalog {
  /// One keychain identity item: reference plus the attributes the
  /// bridge needs.
  internal struct IdentityItem {
    /// The SecIdentity reference, nil when the item carried none.
    internal let identity: SecIdentity?

    /// Keychain label, e.g. the certificate's friendly name.
    internal let label: String

    /// The public key hash the system stores as the application label;
    /// serves as CKA_ID across the identity's three objects.
    internal let keyID: Data
  }

  /// Apple's Secure Enclave tokens carry this prefix; they are not
  /// smartcards and are not exposed as slots.
  private static let secureEnclaveTokenPrefix = "com.apple.setoken"

  /// Refreshes the token list from CryptoTokenKit, keeping slot and
  /// object numbering plus login state stable across calls.
  internal static func refresh(_ registry: inout ModuleRegistry) {
    let watcher = TKTokenWatcher()
    var tokens: [ModuleRegistry.TokenRecord] = []
    let smartcardTokenIDs = watcher.tokenIDs.filter { tokenID in
      !tokenID.hasPrefix(secureEnclaveTokenPrefix)
    }
    for tokenID in smartcardTokenIDs {
      let slotID: CK_SLOT_ID
      if let assigned = registry.slotNumbers[tokenID] {
        slotID = assigned
      } else {
        slotID = registry.nextSlotID
        registry.nextSlotID += 1
        registry.slotNumbers[tokenID] = slotID
      }
      let label = watcher.tokenInfo(forTokenID: tokenID)?.slotName ?? tokenID
      var record = ModuleRegistry.TokenRecord(
        slotID: slotID,
        tokenID: tokenID,
        label: label,
        objects: [])
      if let previous = registry.token(slotID: slotID) {
        record.loggedIn = previous.loggedIn
        record.authenticationContext = previous.authenticationContext
      }
      record.objects = objects(tokenID: tokenID, registry: &registry)
      tokens.append(record)
    }
    registry.tokens = tokens
  }

  /// Fetches the private key bound to a PIN-carrying authentication
  /// context, for tokens logged in with an explicit PIN.
  internal static func authenticatedKey(
    tokenID: String, keyID: Data, context: LAContext
  ) -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrTokenID as String: tokenID,
      kSecAttrApplicationLabel as String: keyID,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnRef as String: true,
      kSecUseAuthenticationContext as String: context,
      kSecUseDataProtectionKeychain as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
      return nil
    }
    guard let result, CFGetTypeID(result) == SecKeyGetTypeID() else { return nil }
    return unsafeDowncast(result, to: SecKey.self)
  }

  /// Builds the object records for one token's identities.
  private static func objects(
    tokenID: String, registry: inout ModuleRegistry
  ) -> [ModuleRegistry.ObjectRecord] {
    var records: [ModuleRegistry.ObjectRecord] = []
    for item in identities(tokenID: tokenID) {
      records += identityRecords(item: item, tokenID: tokenID, registry: &registry)
    }
    return records
  }

  /// Builds the three object records for one identity, or none when
  /// its cryptosystem is not supported.
  private static func identityRecords(
    item: IdentityItem, tokenID: String, registry: inout ModuleRegistry
  ) -> [ModuleRegistry.ObjectRecord] {
    guard let identity = item.identity,
      let certificate = copyCertificate(identity),
      IdentityPolicy.exposes(certificate),
      let publicKey = SecCertificateCopyKey(certificate),
      let shape = IdentityObjects.keyShape(publicKey),
      let privateKey = promptingKey(tokenID: tokenID, item: item)
        ?? copyPrivateKey(identity)
    else { return [] }
    let common: [CK_ATTRIBUTE_TYPE: Data] = [
      CKA_TOKEN: IdentityObjects.flag(true),
      CKA_PRIVATE: IdentityObjects.flag(false),
      CKA_MODIFIABLE: IdentityObjects.flag(false),
      CKA_LABEL: Data(
        KeyLabel.compose(
          keyName: item.label, certificate: certificate, tokenID: tokenID
        ).utf8),
      CKA_ID: item.keyID,
    ]
    let plans = IdentityObjects.blueprints(
      common: common, certificate: certificate, shape: shape, privateKey: privateKey)
    return plans.map { blueprint in
      ModuleRegistry.ObjectRecord(
        handle: stableHandle(
          tokenID: tokenID,
          objectClass: blueprint.objectClass,
          keyID: item.keyID,
          registry: &registry),
        objectClass: blueprint.objectClass,
        attributes: blueprint.attributes,
        keyKind: shape.kind,
        fieldWidth: blueprint.fieldWidth,
        signatureLength: blueprint.objectClass == CKO_CERTIFICATE
          ? 0 : shape.signatureLength,
        privateKey: blueprint.privateKey)
    }
  }

  /// Lists the keychain identities carried by one token.
  private static func identities(tokenID: String) -> [IdentityItem] {
    // Token items live in the data-protection keychain; without the
    // explicit domain the search covers file keychains only and finds
    // nothing.
    let query: [String: Any] = [
      kSecClass as String: kSecClassIdentity,
      kSecAttrTokenID as String: tokenID,
      kSecMatchLimit as String: kSecMatchLimitAll,
      kSecReturnRef as String: true,
      kSecReturnAttributes as String: true,
      kSecUseDataProtectionKeychain as String: true,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let items = result as? [[String: Any]]
    else { return [] }
    return items.compactMap { attributes in
      guard let keyID = attributes[kSecAttrApplicationLabel as String] as? Data else {
        return nil
      }
      let reference = attributes[kSecValueRef as String] as CFTypeRef?
      let identity: SecIdentity?
      if let reference, CFGetTypeID(reference) == SecIdentityGetTypeID() {
        identity = unsafeDowncast(reference, to: SecIdentity.self)
      } else {
        identity = nil
      }
      let label = attributes[kSecAttrLabel as String] as? String ?? tokenID
      return IdentityItem(identity: identity, label: label, keyID: keyID)
    }
  }

  /// Assigns or recalls the handle for one object, stable across
  /// refreshes.
  private static func stableHandle(
    tokenID: String,
    objectClass: CK_OBJECT_CLASS,
    keyID: Data,
    registry: inout ModuleRegistry
  ) -> CK_OBJECT_HANDLE {
    let numberKey = "\(tokenID)/\(objectClass)/\(keyID.base64EncodedString())"
    if let assigned = registry.objectNumbers[numberKey] {
      return assigned
    }
    let handle = registry.nextObjectHandle
    registry.nextObjectHandle += 1
    registry.objectNumbers[numberKey] = handle
    return handle
  }

  /// SecIdentityCopyCertificate as an optional-returning call.
  private static func copyCertificate(_ identity: SecIdentity) -> SecCertificate? {
    var certificate: SecCertificate?
    guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess else {
      return nil
    }
    return certificate
  }

  /// The identity's signing key, carrying the prompt the system PIN
  /// dialog shows.
  ///
  /// Without one the dialog asks for "PIN" and leaves the holder to
  /// guess which of the card's two PINs it means; the token's own key
  /// name says so, in the language the token was minted in.
  private static func promptingKey(tokenID: String, item: IdentityItem) -> SecKey? {
    let context = LAContext()
    context.localizedReason = item.label
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrTokenID as String: tokenID,
      kSecAttrApplicationLabel as String: item.keyID,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnRef as String: true,
      kSecUseDataProtectionKeychain as String: true,
      kSecUseAuthenticationContext as String: context,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let result, CFGetTypeID(result) == SecKeyGetTypeID()
    else { return nil }
    return unsafeDowncast(result, to: SecKey.self)
  }

  /// SecIdentityCopyPrivateKey as an optional-returning call.
  private static func copyPrivateKey(_ identity: SecIdentity) -> SecKey? {
    var key: SecKey?
    guard SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess else { return nil }
    return key
  }
}
