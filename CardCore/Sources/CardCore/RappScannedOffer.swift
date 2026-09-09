// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation
  import RappEngine
  /// Reads a scanned one-use pairing offer without consuming it.
  public enum RappScannedOffer {
    /// One transport candidate carried by a scanned pairing offer.
    public struct Candidate: Sendable, Equatable {
      /// Registered transport profile name.
      public let profile: String
      /// Requester-chosen candidate identifier.
      public let candidateID: String
      /// Decoded stream listener endpoints; empty on other profiles.
      public let streamEndpoints: [String]
      /// Decoded BLE Service UUID; nil on other profiles.
      public let bleServiceUUID: String?
      /// Decoded BLE L2CAP PSM; nil when dynamically assigned or on other profiles.
      public let blePsm: UInt16?

      /// Creates a candidate from already-decoded offer facts.
      public init(
        profile: String,
        candidateID: String,
        streamEndpoints: [String] = [],
        bleServiceUUID: String? = nil,
        blePsm: UInt16? = nil
      ) {
        self.profile = profile
        self.candidateID = candidateID
        self.streamEndpoints = streamEndpoints
        self.bleServiceUUID = bleServiceUUID
        self.blePsm = blePsm
      }
    }

    /// Lists the offer's transport candidates for local selection.
    ///
    /// The decoding bridge is cancelled before returning; the QR bearer
    /// secret does not outlive the call.
    public static func candidates(
      scannedOfferURI: String,
      clock: RappPlatformClock = RappPlatformClock()
    ) throws -> [Candidate] {
      let bridge = try RappPairingBridge.fromScannedOffer(
        uri: scannedOfferURI,
        startedAtMonotonicMs: clock.monotonicMilliseconds()
      )
      defer { bridge.cancelPairing() }
      return bridge.offerCandidates().map { candidate in
        Candidate(
          profile: candidate.profile,
          candidateID: candidate.candidateId,
          streamEndpoints: candidate.streamEndpoints ?? [],
          bleServiceUUID: candidate.bleServiceUUID,
          blePsm: candidate.blePsm
        )
      }
    }
  }
#endif
