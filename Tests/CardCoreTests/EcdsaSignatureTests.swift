// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct EcdsaSignatureTests {
  @Test
  internal func refusesEmptyAndOddLength() {
    #expect(EcdsaSignature.derFromRawConcatenation(Data()) == nil)
    #expect(EcdsaSignature.derFromRawConcatenation(WireHex.data("AABBCC")) == nil)
  }

  @Test
  internal func encodesSmallPositiveIntegers() {
    // r=0x01, s=0x02 -> SEQUENCE { INTEGER 1, INTEGER 2 }.
    let der = EcdsaSignature.derFromRawConcatenation(WireHex.data("0102"))
    #expect(der == WireHex.data("3006020101020102"))
  }

  @Test
  internal func prependsZeroWhenHighBitSet() {
    // r=0x80 has the high bit set -> 02 02 00 80 (positive).
    let der = EcdsaSignature.derFromRawConcatenation(WireHex.data("8001"))
    #expect(der == WireHex.data("300702020080020101"))
  }

  @Test
  internal func stripsLeadingZeros() {
    // r=00 05 -> INTEGER 05 (leading zero removed).
    let der = EcdsaSignature.derFromRawConcatenation(WireHex.data("00050006"))
    #expect(der == WireHex.data("3006020105020106"))
  }

  @Test
  internal func encodesFullP384Signature() throws {
    // 96 raw bytes -> a DER SEQUENCE; length is long-form (0x81).
    let raw = Data((0..<96).map { UInt8($0 % 256) })
    let der = try #require(EcdsaSignature.derFromRawConcatenation(raw))
    #expect(der.first == 0x30)
    // r starts at 0x00 (index 0), so it strips to a small integer; the
    // point is a well-formed structure that re-parses.
    #expect(der.count > 96)
  }

  @Test
  internal func derBecomesAPaddedCoordinatePair() {
    // SEQUENCE { INTEGER 0x00AABB, INTEGER 0x01 } - the first with a
    // DER sign byte that is padding, not magnitude.
    let der = WireHex.data("30080203" + "00AABB" + "020101")
    let pair = EcdsaSignature.rawConcatenation(fromDer: der, coordinateOctets: 4)
    #expect(pair == WireHex.data("0000AABB" + "00000001"))
    // A coordinate wider than the field is a curve mismatch.
    #expect(
      EcdsaSignature.rawConcatenation(fromDer: der, coordinateOctets: 1) == nil
    )
    // Not a SEQUENCE of exactly two INTEGERs.
    #expect(
      EcdsaSignature.rawConcatenation(
        fromDer: WireHex.data("3000"), coordinateOctets: 4
      ) == nil
    )
    // Trailing bytes after the SEQUENCE are refused.
    #expect(
      EcdsaSignature.rawConcatenation(
        fromDer: der + WireHex.data("00"), coordinateOctets: 4
      ) == nil
    )
  }

  @Test
  internal func rawSurvivesTheDerRoundTrip() throws {
    let raw = Data((1..<97).map { UInt8($0) })
    let der = try #require(EcdsaSignature.derFromRawConcatenation(raw))
    let back = EcdsaSignature.rawConcatenation(fromDer: der, coordinateOctets: 48)
    #expect(back == raw)
  }
}
