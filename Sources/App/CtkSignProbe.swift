// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import CryptoKit
  import CryptoTokenKit
  import Foundation
  import LocalAuthentication
  import Security

  /// Diagnostic that signs through the real token-extension path.
  ///
  /// Unlike `SignProbe` (which drives the card directly), this looks up the
  /// published identity's private key in the keychain and calls
  /// `SecKeyCreateSignature`. That routes through the extension exactly as
  /// Safari does - `supports` -> `beginAuth` (the system PIN sheet) ->
  /// `sign` - then verifies the returned signature against the leaf. Run
  /// as ``DebugLaunchMode/ctkSignProbe``, which owns the flag, the
  /// printing and the exit status; the PIN sheet is entered by hand on the
  /// device.
  ///
  /// A scene-bound mode: the system needs the app's run loop to present
  /// that sheet, so ``DebugSceneRunnerView`` hosts it and takes the
  /// blocking signature off the main thread.
  internal enum CtkSignProbe {
    private static let tokenDiscoveryRetryCount = 30
    private static let tokenDiscoveryPollIntervalSeconds = 0.1

    /// What the extension did with a signature request.
    internal static func report() -> DebugModeReport {
      DebugModeReport(lines: Self.collect())
    }

    private static func collect() -> [String] {
      var lines: [String] = []
      let watcher = TKTokenWatcher()
      var tokens: [String] = []
      for _ in 0..<tokenDiscoveryRetryCount {
        tokens = watcher.tokenIDs.sorted().filter { $0.hasPrefix("fi.refineid.") }
        if !tokens.isEmpty { break }
        Thread.sleep(forTimeInterval: tokenDiscoveryPollIntervalSeconds)
      }
      lines.append("refineid tokens: \(tokens.count) - \(tokens.joined(separator: ", "))")
      guard let tokenID = tokens.first else {
        return lines + ["FAIL: no refineid token registered"]
      }

      lines.append(contentsOf: certificateReferenceReport())
      let context = LAContext()
      context.localizedReason = String(localized: "Test the RefineID identity token")
      guard let privateKey = copyTokenKey(tokenID: tokenID, context: context) else {
        return lines + dumpTokenKeychain() + ["FAIL: no refineid key in keychain"]
      }
      guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
        return lines + ["FAIL: could not derive the public key"]
      }
      return lines + signThroughExtension(privateKey: privateKey, publicKey: publicKey)
    }

    private static func signThroughExtension(privateKey: SecKey, publicKey: SecKey) -> [String] {
      let digest = Data(SHA384.hash(data: Data("RefineID CTK path test".utf8)))
      let algorithm = SecKeyAlgorithm.ecdsaSignatureDigestX962SHA384
      guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
        return ["FAIL: token key does not support the algorithm (supports said NO)"]
      }
      var error: Unmanaged<CFError>?
      let created = SecKeyCreateSignature(privateKey, algorithm, digest as CFData, &error)
      guard let signature = created as Data? else {
        let reason = error?.takeRetainedValue().localizedDescription ?? "unknown"
        return ["FAIL: SecKeyCreateSignature - \(reason)"]
      }
      var verifyError: Unmanaged<CFError>?
      let valid = SecKeyVerifySignature(
        publicKey,
        algorithm,
        digest as CFData,
        signature as CFData,
        &verifyError
      )
      guard valid else {
        let reason = verifyError?.takeRetainedValue().localizedDescription ?? "unknown"
        return ["signature: \(signature.count) B - FAIL: does not verify - \(reason)"]
      }
      return ["signature: \(signature.count) DER bytes - EXTENSION SIGN VERIFIES OK"]
    }

    /// Lists every item class in the token access group with its token ID
    /// and label, so a missing identity is diagnosable rather than silent.
    private static func dumpTokenKeychain() -> [String] {
      var lines: [String] = []
      let classes: [(CFString, String)] = [
        (kSecClassIdentity, "identity"),
        (kSecClassCertificate, "certificate"),
        (kSecClassKey, "key"),
      ]
      for (itemClass, name) in classes {
        let query: [CFString: Any] = [
          kSecClass: itemClass,
          kSecAttrAccessGroup: kSecAttrAccessGroupToken,
          kSecReturnAttributes: true,
          kSecMatchLimit: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[CFString: Any]] else {
          lines.append("\(name): status \(status)")
          continue
        }
        lines.append("\(name): \(items.count) item(s)")
        for item in items {
          let tokenID = (item[kSecAttrTokenID] as? String) ?? "-"
          let label = (item[kSecAttrLabel] as? String) ?? "-"
          lines.append("  tokenID=\(tokenID) label=\(label)")
        }
      }
      return lines
    }

    /// Runs Apple's minimal token-entitlement diagnostic query unchanged.
    ///
    /// A successful attribute-only query proves that ctkd indexed the
    /// extension's publication. A certificate reference additionally
    /// crosses the token-access boundary. Keeping this query free of token
    /// filters and authentication options makes its result directly
    /// comparable with Apple's documented troubleshooting query.
    private static func certificateReferenceReport() -> [String] {
      let query: [CFString: Any] = [
        kSecClass: kSecClassCertificate,
        kSecAttrAccessGroup: kSecAttrAccessGroupToken,
        kSecMatchLimit: kSecMatchLimitAll,
        kSecReturnRef: true,
      ]
      var result: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      guard status == errSecSuccess else {
        return ["certificate/ref exact query: status \(status)"]
      }
      if let references = result as? [Any] {
        return ["certificate/ref exact query: \(references.count) reference(s)"]
      }
      return ["certificate/ref exact query: one reference"]
    }

    /// The key as a TLS client would reach it: find the identity, take
    /// its private key.
    ///
    /// This is what Safari does, and it is what this probe exists to
    /// imitate. On macOS it does not work here, and the reason is worth
    /// knowing before the next person spends an evening on it: reading
    /// the *attributes* of a token item needs nothing, while getting a
    /// *reference* asks `ctkd` to vend the key, and that is refused to
    /// an app without the `com.apple.token` keychain access group. This
    /// build has no such entitlement -- the signing profile will not
    /// carry it -- so the probe can list an identity it cannot use.
    /// Safari holds the entitlement, so what the probe cannot do says
    /// nothing about whether the login works.
    private static func identityKey(
      tokenID: String,
      context: LAContext
    ) -> SecKey? {
      // Attributes and references together, unfiltered, then matched
      // here. Filtering the query by `kSecAttrTokenID` returned nothing
      // for an identity the same query returns when asked for
      // everything, so the filter is applied to the results instead.
      let query: [CFString: Any] = [
        kSecClass: kSecClassIdentity,
        kSecAttrAccessGroup: kSecAttrAccessGroupToken,
        kSecReturnRef: true,
        kSecReturnAttributes: true,
        kSecMatchLimit: kSecMatchLimitAll,
        kSecUseAuthenticationContext: context,
      ]
      var found: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &found)
      guard status == errSecSuccess, let matches = found as? [[CFString: Any]] else {
        DebugConsole.emit("identity/attrs+ref: status \(status)")
        return nil
      }
      for match in matches {
        guard
          match[kSecAttrTokenID] as? String == tokenID,
          let untyped = match[kSecValueRef],
          CFGetTypeID(untyped as CFTypeRef) == SecIdentityGetTypeID()
        else {
          continue
        }
        let identity = unsafeDowncast(untyped as AnyObject, to: SecIdentity.self)
        var key: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess else { continue }
        return key
      }
      return nil
    }

    private static func copyTokenKey(
      tokenID: String,
      context: LAContext
    ) -> SecKey? {
      if let key = Self.identityKey(tokenID: tokenID, context: context) {
        return key
      }
      // The token's key lives in the token access group; the query must
      // name it (and the app holds the com.apple.token keychain group
      // entitlement) or SecItemCopyMatching never returns it. Several
      // query shapes are tried in order and the working one reported -
      // iOS is picky about which attribute filters and return forms it
      // honors for token items.
      let variants: [(String, [CFString: Any])] = [
        (
          "key/ref",
          [
            kSecClass: kSecClassKey,
            kSecAttrAccessGroup: kSecAttrAccessGroupToken,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
          ]
        ),
        (
          "key/tokenID-no-group",
          [
            kSecClass: kSecClassKey,
            kSecAttrTokenID: tokenID,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
          ]
        ),
        (
          "key/attrs+ref",
          [
            kSecClass: kSecClassKey,
            kSecAttrAccessGroup: kSecAttrAccessGroupToken,
            kSecReturnAttributes: true,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
          ]
        ),
      ]
      for (name, query) in variants {
        if let key = runKeyQuery(name: name, query: query) {
          return key
        }
      }
      return nil
    }

    private static func runKeyQuery(name: String, query: [CFString: Any]) -> SecKey? {
      var result: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      guard status == errSecSuccess, let found = result else {
        DebugConsole.emit("\(name): status \(status)")
        return nil
      }
      let reference: CFTypeRef
      if let attributes = found as? [CFString: Any] {
        guard let fromAttributes = attributes[kSecValueRef] else {
          DebugConsole.emit("\(name): attributes without ref (keys: \(attributes.keys.count))")
          return nil
        }
        reference = fromAttributes as CFTypeRef
      } else {
        reference = found
      }
      guard CFGetTypeID(reference) == SecKeyGetTypeID() else {
        DebugConsole.emit("\(name): non-key ref")
        return nil
      }
      DebugConsole.emit("\(name): got the key ref")
      // Type-checked immediately above; this cast cannot fail.
      return unsafeDowncast(reference as AnyObject, to: SecKey.self)
    }
  }

#endif
