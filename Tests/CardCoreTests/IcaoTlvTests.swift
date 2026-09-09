// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// The BER walker for a travel document's files, against length octets a
/// malfunctioning or hostile card could return.
@Suite
internal struct IcaoTlvTests {
  @Test
  internal func readsAFourOctetLength() throws {
    let record = try #require(
      IcaoTlv(Data([0x61, 0x84, 0x00, 0x00, 0x00, 0x02, 0xAA, 0xBB])).outermost)
    #expect(record.tag == 0x61)
    #expect(record.content == 6..<8)
  }

  @Test
  internal func refusesMoreLengthOctetsThanALengthCanCarry() {
    // Eight length octets with a high top byte shift the length into the
    // sign bit; the walker must answer nothing rather than trap on a
    // reversed range.
    let malformed = Data([0x61, 0x88, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    #expect(IcaoTlv(malformed).outermost == nil)
  }

  @Test
  internal func refusesFiveLengthOctets() {
    let malformed = Data([0x61, 0x85, 0x00, 0x00, 0x00, 0x00, 0x01, 0xAA])
    #expect(IcaoTlv(malformed).outermost == nil)
  }
}
