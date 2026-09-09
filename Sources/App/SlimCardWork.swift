// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_SLIM_RELAY && REFINEID_LOCAL_CARD && os(iOS)

  import CardCore
  import Foundation

  /// Reaches the card for one slim-relay request.
  ///
  /// The certificate is answered from what this device already read while
  /// setting its own identity up, so a peer asking for it does not cost the
  /// holder a card hold. A signature has to reach the card, because only the
  /// card holds the key.
  internal enum SlimCardWork {
    /// Performs `request` and names what came back.
    internal static func perform(
      _ request: PersistentRelayMessage
    ) async -> PersistentRelayMessage {
      switch request {
      case .identityRequest(let requestID):
        guard let primed = PrimeStore.storedIdentities().first else {
          return .failure(requestID: requestID, reason: .cardUnavailable)
        }
        return .identityResponse(
          requestID: requestID,
          certificateDER: primed.certDER,
          cardSerial: RappPhoneProxyDispatcher.storedTokenSerial()
        )

      case .signatureRequest(let requestID, let profile, let algorithm, let digest):
        return await sign(
          requestID: requestID, profile: profile, algorithm: algorithm, digest: digest)

      case .failure, .identityResponse, .signatureResponse:
        return .failure(requestID: request.requestID, reason: .unsupportedAlgorithm)
      }
    }

    private static func sign(
      requestID: UUID,
      profile: PersistentRelayCardProfile,
      algorithm: PersistentRelaySigningAlgorithm,
      digest: Data
    ) async -> PersistentRelayMessage {
      guard
        let relayAlgorithm = RappOperationDriver.SignatureAlgorithm(algorithm.signingAlgorithm)
      else {
        return .failure(requestID: requestID, reason: .unsupportedAlgorithm)
      }
      let accessNumber = CardCredentialStore.displayedCardAccessNumber()
      let outcome = await RappCardExecutor.browserAuthentication(
        cardAccessNumber: accessNumber,
        keyProfile: RappOperationDriver.KeyProfile(profile.cardKeyProfile),
        algorithm: relayAlgorithm,
        digest: digest
      )
      switch outcome {
      case .result(let signature):
        return .signatureResponse(requestID: requestID, signature: signature)

      case .rejected(.cardAccessNumber):
        return .failure(requestID: requestID, reason: .wrongCardAccessNumber)

      case .rejected:
        return .failure(requestID: requestID, reason: .pin1Rejected(remaining: nil))

      case .refusedBeforeCredentialTransmit:
        return .failure(requestID: requestID, reason: .cardUnavailable)

      case .completionAmbiguous:
        return .failure(requestID: requestID, reason: .communication)
      }
    }
  }

#endif
