// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The origin-bound challenge rule for authentication signs (DVV SCS
/// specification v1.3 §2.1, §3.7).
@Suite
internal struct ScsChallengeTests {
  private static let origin = "https://dvv.fineid.fi"

  /// 64 characters, the specification's floor.
  private func longNonce() -> String {
    String(repeating: "a1b2c3d4", count: 8)
  }

  private func refusal(_ challenge: String, origin: String?) -> String? {
    ScsAuthenticationChallenge.refusal(
      content: Data(challenge.utf8), origin: origin)
  }

  @Test
  internal func acceptsTheBoundChallenge() {
    #expect(refusal("\(Self.origin);\(longNonce())", origin: Self.origin) == nil)
  }

  @Test
  internal func rejectsAMissingOriginHeader() {
    let reason = refusal("\(Self.origin);\(longNonce())", origin: nil)
    #expect(reason?.contains("missing Origin") == true)
  }

  @Test
  internal func rejectsAnOriginMismatch() {
    let reason = refusal("https://attacker.example;\(longNonce())", origin: Self.origin)
    #expect(reason?.contains("does not match") == true)
  }

  @Test
  internal func rejectsAShortNonce() {
    let reason = refusal("\(Self.origin);tooshort", origin: Self.origin)
    #expect(reason?.contains("too short") == true)
  }

  @Test
  internal func rejectsAMissingSeparator() {
    let reason = refusal(Self.origin + longNonce(), origin: Self.origin)
    #expect(reason?.contains("; separator") == true)
  }

  @Test
  internal func rejectsASpaceSeparator() {
    // The v1.3 changelog makes the semicolon mandatory; the space
    // form some older services sent is refused.
    let reason = refusal("\(Self.origin) \(longNonce())", origin: Self.origin)
    #expect(reason?.contains("; separator") == true)
  }

  @Test
  internal func rejectsNonUtf8Content() {
    let reason = ScsAuthenticationChallenge.refusal(
      content: Data([0xFF, 0xFE, 0x00]), origin: Self.origin)
    #expect(reason?.contains("UTF-8") == true)
  }
}
