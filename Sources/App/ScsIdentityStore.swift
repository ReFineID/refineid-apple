// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)
  import CardCore
  import Foundation
  import Security

  /// The keychain-backed TLS identity of the localhost SCS.
  ///
  /// The identity is generated once - a P-256 key plus a self-signed
  /// certificate carrying the DVV SCS specification v1.3 §2.3
  /// attributes - and persisted in the login keychain, so browser
  /// trust granted once survives restarts. On first creation the
  /// store also asks the system to trust the certificate for this
  /// user; that request shows a system prompt, and refusing it
  /// leaves a certificate the holder can still trust manually in
  /// Keychain Access.
  internal enum ScsIdentityStore {
    /// The keychain label naming the identity's parts.
    private static let label = "RefineID SCS localhost"

    /// The server key's strength; the curve is P-256.
    private static let keySizeBits = 256

    /// The stored identity, minting it on first use.
    internal static func obtain() -> SecIdentity? {
      if let existing = existingIdentity() {
        return existing
      }
      guard mint() else { return nil }
      return existingIdentity()
    }

    /// The identity already in the keychain, when there is one.
    ///
    /// Every identity is enumerated and matched on its certificate's
    /// common name, because neither narrowing attribute is
    /// trustworthy here: an identity search does not filter on the
    /// label at all - it answers whichever identity the keychain
    /// lists first, on a developer's machine the code-signing one -
    /// and a certificate's stored label comes from its subject
    /// rather than from what the caller passed at store time. The
    /// subject is the one handle the keychain cannot rewrite.
    private static func existingIdentity() -> SecIdentity? {
      let query: [String: Any] = [
        kSecClass as String: kSecClassIdentity,
        kSecMatchLimit as String: kSecMatchLimitAll,
        kSecReturnRef as String: true,
      ]
      var items: CFTypeRef?
      guard
        SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
        let candidates = items as? [Any]
      else {
        return nil
      }
      for candidate in candidates {
        guard CFGetTypeID(candidate as CFTypeRef) == SecIdentityGetTypeID() else {
          continue
        }
        // The type identifier was checked above; the bit pattern is
        // an identity reference.
        let identity = unsafeDowncast(candidate as AnyObject, to: SecIdentity.self)
        var certificate: SecCertificate?
        guard
          SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
          let certificate
        else {
          continue
        }
        var commonName: CFString?
        guard
          SecCertificateCopyCommonName(certificate, &commonName) == errSecSuccess,
          commonName as String? == ScsLocalhostCertificate.commonName
        else {
          continue
        }
        return identity
      }
      return nil
    }

    /// Generates the key, builds the certificate, stores both, and
    /// requests user trust.
    private static func mint() -> Bool {
      let keyAttributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: keySizeBits,
        kSecAttrLabel as String: label,
        kSecPrivateKeyAttrs as String: [
          kSecAttrIsPermanent as String: true,
          kSecAttrApplicationTag as String: Data("fi.refineid.scs.localhost".utf8),
        ],
      ]
      guard let key = SecKeyCreateRandomKey(keyAttributes as CFDictionary, nil) else {
        ScsLog.error("identity: key generation failed")
        return false
      }
      guard let certificate = builtCertificate(for: key) else { return false }
      let addStatus = SecItemAdd(
        [
          kSecClass as String: kSecClassCertificate,
          kSecValueRef as String: certificate,
          kSecAttrLabel as String: label,
        ] as CFDictionary,
        nil
      )
      guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
        ScsLog.error("identity: certificate store failed (\(addStatus))")
        return false
      }
      requestUserTrust(certificate)
      return true
    }

    /// Builds the self-signed localhost certificate around `key`.
    private static func builtCertificate(for key: SecKey) -> SecCertificate? {
      guard
        let publicKey = SecKeyCopyPublicKey(key),
        let publicRepresentation = SecKeyCopyExternalRepresentation(publicKey, nil)
      else {
        ScsLog.error("identity: public key export failed")
        return nil
      }
      var serialValue = UInt64.random(in: UInt64.min...UInt64.max)
      let serial = Data(bytes: &serialValue, count: MemoryLayout<UInt64>.size)
      let spki = ScsLocalhostCertificate.subjectPublicKeyInfo(
        fromX963: publicRepresentation as Data)
      var signingFailed = false
      let certificateDer = ScsLocalhostCertificate.make(
        subjectPublicKeyInfo: spki,
        serialNumber: serial,
        from: Date()
      ) { tbs in
        guard
          let signature = SecKeyCreateSignature(
            key, .ecdsaSignatureMessageX962SHA256, tbs as CFData, nil)
        else {
          signingFailed = true
          return Data()
        }
        return signature as Data
      }
      guard
        !signingFailed,
        let certificate = SecCertificateCreateWithData(nil, certificateDer as CFData)
      else {
        ScsLog.error("identity: certificate build failed")
        return nil
      }
      return certificate
    }

    /// Asks the system to trust the certificate for this user; a
    /// refusal is logged, not fatal - the SCS still runs, and the
    /// browser will refuse until the certificate is trusted in
    /// Keychain Access.
    private static func requestUserTrust(_ certificate: SecCertificate) {
      let trustStatus = SecTrustSettingsSetTrustSettings(
        certificate, SecTrustSettingsDomain.user, nil)
      if trustStatus == errSecSuccess {
        ScsLog.info("identity: localhost certificate trusted for this user")
      } else {
        ScsLog.error(
          "identity: user trust not granted (\(trustStatus)); trust the "
            + "\(label) certificate in Keychain Access to let the browser connect")
      }
    }
  }
#endif
