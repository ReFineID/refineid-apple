// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import XCTest

#if canImport(RappEngine)
  import RappEngine
  /// Round-trips a requester offer carrying an Apple-peer and a stream
  /// candidate through the QR URI and the scanned-offer candidate listing.
  internal final class RappScannedOfferTests: XCTestCase {
    private static let offerLifetimeMilliseconds: UInt64 = 60_000
    private static let applePeerProfile = "apple-peer-v1"
    private static let applePeerCandidateID = "apple-peer-v1.nearby"
    private static let streamCandidateID = "stream-1"
    private static let streamEndpoints = ["192.0.2.7:4711", "[2001:db8::17]:4711"]
    private static let credentialProfiles = ["fi.refineid.card-status.v1"]

    /// Deterministic-CBOR initial byte of an empty map.
    private static let emptyMapCBOR = Data([0b1010_0000])
    private static let oneEntryMapHeader: UInt8 = 0b1010_0001
    private static let shortTextHeaderBase: UInt8 = 0b0110_0000
    private static let shortArrayHeaderBase: UInt8 = 0b1000_0000
    /// Largest count expressible in a one-byte CBOR header.
    private static let maximumShortCount = 23

    private static func shortText(_ value: String) -> Data {
      let bytes = Data(value.utf8)
      precondition(bytes.count <= maximumShortCount)
      return Data([shortTextHeaderBase | UInt8(bytes.count)]) + bytes
    }

    private static func streamParametersCBOR(endpoints: [String]) -> Data {
      precondition(endpoints.count <= maximumShortCount)
      var encoded = Data([oneEntryMapHeader])
      encoded.append(shortText("endpoints"))
      encoded.append(shortArrayHeaderBase | UInt8(endpoints.count))
      for endpoint in endpoints {
        encoded.append(shortText(endpoint))
      }
      return encoded
    }

    internal func testScannedOfferListsCandidatesWithDecodedStreamEndpoints() throws {
      let entropy = RappPlatformEntropy()
      let clock = RappPlatformClock()
      let startedAt = clock.monotonicMilliseconds()
      let bridge = try RappPairingBridge.createRequesterOffer(
        offerId: entropy.offerID(),
        pairingSecret: entropy.pairingSecret(),
        profiles: Self.credentialProfiles,
        transports: [
          RappTransportCandidate(
            profile: Self.applePeerProfile,
            candidateId: Self.applePeerCandidateID,
            parametersCbor: Self.emptyMapCBOR
          ),
          RappTransportCandidate(
            profile: rappStreamProfileName(),
            candidateId: Self.streamCandidateID,
            parametersCbor: Self.streamParametersCBOR(endpoints: Self.streamEndpoints)
          ),
        ],
        offerTtlMs: Self.offerLifetimeMilliseconds,
        startedAtMonotonicMs: startedAt
      )
      let uri = try bridge.offerUri(nowMonotonicMs: clock.monotonicMilliseconds())
      bridge.cancelPairing()

      let candidates = try RappScannedOffer.candidates(scannedOfferURI: uri)
      XCTAssertEqual(candidates.count, 2)

      let applePeer = try XCTUnwrap(
        candidates.first { $0.profile == Self.applePeerProfile }
      )
      XCTAssertEqual(applePeer.candidateID, Self.applePeerCandidateID)
      XCTAssertEqual(applePeer.streamEndpoints, [])

      let stream = try XCTUnwrap(
        candidates.first { $0.profile == rappStreamProfileName() }
      )
      XCTAssertEqual(stream.candidateID, Self.streamCandidateID)
      XCTAssertEqual(stream.streamEndpoints, Self.streamEndpoints)
    }
  }
#endif
