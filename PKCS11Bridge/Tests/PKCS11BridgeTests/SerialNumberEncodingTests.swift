// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import Testing

@testable import PKCS11Bridge

/// CKA_SERIAL_NUMBER carries the DER encoding of the serial-number
/// INTEGER, while Security.framework hands out only its content octets;
/// the attribute must get its tag and length back or byte-exact
/// issuer-plus-serial lookups never match.
@Suite
internal struct SerialNumberEncodingTests {
  @Test
  internal func integerEncodingPrependsTagAndLength() {
    let content = Data([0x00, 0xAB, 0xCD])
    #expect(
      Asn1.integerEncoded(content: content) == Data([0x02, 0x03, 0x00, 0xAB, 0xCD]))
  }

  @Test
  internal func integerEncodingUsesLongFormPastTheShortBound() {
    let content = Data(repeating: 0x5A, count: 200)
    let encoded = Asn1.integerEncoded(content: content)
    #expect(encoded.prefix(3) == Data([0x02, 0x81, 200]))
    #expect(encoded.dropFirst(3) == content)
  }

  @Test
  internal func integerEncodingRoundTripsThroughTheReader() {
    let content = Data([0x00, 0x8F, 0x01])
    let encoded = Asn1.integerEncoded(content: content)
    var index = 0
    // The reader strips the sign padding, which is how PKCS#11 carries
    // unsigned values elsewhere; the wire form keeps it.
    #expect(Asn1.integer(encoded, &index) == Data([0x8F, 0x01]))
    #expect(index == encoded.count)
  }
}
