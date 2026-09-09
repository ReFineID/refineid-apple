// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import RappEngine
import XCTest

internal final class RappOfferExpiryTests: XCTestCase {
  internal func testOfferExpiresAtItsMonotonicDeadline() throws {
    let bridge = try makeBridge(startedAt: 1_000, lifetime: 100)

    XCTAssertNoThrow(try bridge.offerUri(nowMonotonicMs: 1_099))
    assertOfferExpired {
      _ = try bridge.offerUri(nowMonotonicMs: 1_100)
    }
  }

  internal func testOfferCannotOutliveDeadlineDuringNoiseHandshake() throws {
    let bridge = try makeBridge(startedAt: 1_000, lifetime: 100)

    try bridge.begin(candidateId: "candidate", nowMonotonicMs: 1_099)
    assertOfferExpired {
      _ = try bridge.writeHandshakeFrame(nowMonotonicMs: 1_100)
    }
  }

  private func makeBridge(startedAt: UInt64, lifetime: UInt64) throws -> RappPairingBridge {
    try RappPairingBridge.createRequesterOffer(
      offerId: Data(repeating: 0x11, count: 32),
      pairingSecret: Data(repeating: 0x22, count: 32),
      profiles: ["fi.refineid.card-status.v1"],
      transports: [
        RappTransportCandidate(
          profile: "local-quic-v1",
          candidateId: "candidate",
          parametersCbor: Data([0xa0])
        )
      ],
      offerTtlMs: lifetime,
      startedAtMonotonicMs: startedAt
    )
  }

  private func assertOfferExpired(
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () throws -> Void
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
      guard case RappBindingError.OfferExpired = error else {
        XCTFail("Expected OfferExpired, got \(error)", file: file, line: line)
        return
      }
    }
  }
}
