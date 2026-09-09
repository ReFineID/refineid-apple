// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)
  import CardCore
  import CryptoKit
  import Foundation
  import Security

  /// The production SCS signing backend: one card session per
  /// operation, the retry floor before any credential, and the app's
  /// own PIN prompt.
  ///
  /// `@unchecked Sendable` is the audit, not a shrug: every call
  /// arrives on the SCS server's one serial queue, so the leaf
  /// caches are never touched concurrently.
  internal final class ScsCardBackend: ScsSigningBackend, @unchecked Sendable {
    /// Carries a value across the semaphore boundary; sound because
    /// the semaphore serialises the write before the wait returns.
    private final class Box<Value>: @unchecked Sendable {
      var value: Value

      init(_ value: Value) {
        self.value = value
      }
    }

    private var authenticationLeaf: Data?
    private var qualifiedLeaf: Data?

    /// One floor-guarded, PIN-prompted sign inside an open session.
    private static func performSign(
      _ operations: CardOperations,
      purpose: ScsSignPurpose,
      digest: Data,
      algorithm: SigningAlgorithm,
      expectedSignatureLength: ExpectedResponseLength?
    ) -> Result<Data, ScsBackendFailure> {
      if let refused = contextRefusal(operations, purpose: purpose) {
        return .failure(refused)
      }
      let role: CredentialRole = purpose == .authentication ? .pin1 : .pin2
      guard
        let probe = try? operations.probeRetryCounter(role: role),
        RetryFloor.evaluate(probeOutcome: probe) == .proceed
      else {
        return .failure(.credentialRefused("credential retry state refuses the sign"))
      }
      guard let entered = ScsPinPrompt.request(role: role) else {
        return .failure(.credentialRefused("PIN entry was cancelled"))
      }
      do {
        switch purpose {
        case .authentication:
          guard let pin = Pin1(digits: entered) else {
            return .failure(.credentialRefused("PIN format invalid"))
          }
          try operations.verifyPin1(pin.consumeForSingleTransmission())
          return .success(
            try operations.computeAuthenticationSignature(
              overDigest: digest,
              algorithm: algorithm,
              expectedSignatureLength: expectedSignatureLength
            )
          )

        case .qualified:
          guard let pin = Pin2(digits: entered) else {
            return .failure(.credentialRefused("PIN format invalid"))
          }
          try operations.verifyPin2(pin.consumeForSingleTransmission())
          return .success(
            try operations.computeQualifiedSignature(
              overDigest: digest,
              algorithm: algorithm,
              expectedSignatureLength: expectedSignatureLength
            )
          )
        }
      } catch {
        return .failure(refusal(from: error))
      }
    }

    /// Enters the directory the sign must run in, when the card has
    /// one.
    ///
    /// The organization card's qualified-signature service lives in
    /// DF.ESIGN (S4-2 v4.0 §4.6.21): the ceremony enters it before
    /// the floor probe so PIN SIG is verified and spent in the
    /// context the signature runs in.
    private static func contextRefusal(
      _ operations: CardOperations,
      purpose: ScsSignPurpose
    ) -> ScsBackendFailure? {
      guard
        purpose == .qualified,
        (try? operations.resolveCredentialReferences()) == .organization
      else {
        return nil
      }
      do {
        try operations.selectEsignDirectory()
        return nil
      } catch {
        ScsLog.error("backend: signature directory unavailable (\(error))")
        return .signingUnavailable("signature directory unavailable")
      }
    }

    /// Maps a refused verify or sign to the backend's failure pair,
    /// logging the card's own answer for the unexpected class.
    private static func refusal(from error: any Error) -> ScsBackendFailure {
      switch error {
      case CardOperationError.pinRejected(let remaining):
        return .credentialRefused(
          "PIN rejected; \(remaining.attemptsRemaining) attempts left")

      case CardOperationError.pinBlocked:
        return .credentialRefused("credential blocked")

      case CardOperationError.credentialInvalidated:
        return .credentialRefused("credential invalidated")

      default:
        ScsLog.error("backend: sign chain failed (\(error))")
        return .signingUnavailable("sign chain failed")
      }
    }

    internal func certificateChain(for purpose: ScsSignPurpose) -> [Data] {
      guard let leaf = leaf(for: purpose) else { return [] }
      return [leaf]
    }

    internal func keyAlgorithm(for purpose: ScsSignPurpose) -> ScsKeyAlgorithm {
      guard let profile = profile(for: purpose) else { return .rsa }
      switch profile {
      case .ecdsaP256, .ecdsaP384:
        return .ecdsa

      case .rsa2048, .rsa3072:
        return .rsa
      }
    }

    internal func sign(
      purpose: ScsSignPurpose,
      hash: SigningHash,
      data: Data
    ) throws -> Data {
      let digest: Data
      switch hash {
      case .sha1, .sha224:
        throw ScsBackendFailure.signingUnavailable("unsupported digest")

      case .sha256:
        digest = Data(SHA256.hash(data: data))

      case .sha384:
        digest = Data(SHA384.hash(data: data))

      case .sha512:
        digest = Data(SHA512.hash(data: data))
      }
      guard let profile = profile(for: purpose) else {
        throw ScsBackendFailure.signingUnavailable("card certificate unavailable")
      }
      let scheme: SigningScheme
      switch profile {
      case .ecdsaP256, .ecdsaP384:
        scheme = .ecdsa

      case .rsa2048, .rsa3072:
        scheme = .rsaPkcs1
      }
      let algorithm = SigningAlgorithm(hash: hash, scheme: scheme)
      let expected = profile.expectedSignatureLength
      let outcome: Result<Data, ScsBackendFailure>? = withCard { operations in
        Self.performSign(
          operations,
          purpose: purpose,
          digest: digest,
          algorithm: algorithm,
          expectedSignatureLength: expected
        )
      }
      guard let outcome else {
        throw ScsBackendFailure.signingUnavailable("no card session")
      }
      return try outcome.get()
    }

    /// The cached leaf for `purpose`, read from the card on first
    /// use.
    private func leaf(for purpose: ScsSignPurpose) -> Data? {
      switch purpose {
      case .authentication:
        if authenticationLeaf == nil {
          authenticationLeaf = readLeaf(slot: .authentication)
        }
        return authenticationLeaf

      case .qualified:
        if qualifiedLeaf == nil {
          qualifiedLeaf = readLeaf(slot: .qualifiedSignature)
        }
        return qualifiedLeaf
      }
    }

    private func profile(for purpose: ScsSignPurpose) -> CardKeyProfile? {
      guard
        let leaf = leaf(for: purpose),
        let certificate = SecCertificateCreateWithData(nil, leaf as CFData)
      else {
        return nil
      }
      return CardKeyProfile.resolve(fromCertificate: certificate)
    }

    private func readLeaf(slot: CertificateSlot) -> Data? {
      withCard { operations in
        try? operations.readCertificate(slot)
      }
    }

    /// Bridges the synchronous backend to the app's async card
    /// session, blocking the SCS worker - never the main thread -
    /// until the card answers.
    private func withCard<Answer: Sendable>(
      _ work: @escaping @Sendable (CardOperations) -> Answer?
    ) -> Answer? {
      let semaphore = DispatchSemaphore(value: 0)
      let box = Box<Answer?>(nil)
      Task {
        box.value = await CardMaintenance.onCard(work)
        semaphore.signal()
      }
      semaphore.wait()
      return box.value
    }
  }
#endif
