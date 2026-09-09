// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct ApplicationIdentifierTests {
  @Test
  internal func fineidApplicationConstantExists() {
    // The DVV-documented IAS "PKCS-15" AID parses to 12 bytes.
    let aid = ApplicationIdentifier.fineidApplication
    #expect(aid == ApplicationIdentifier(hexDigits: "A000000063504B43532D3135"))
  }

  @Test
  internal func refusesWrongLengths() {
    // Four bytes: below the five-byte RID minimum.
    #expect(ApplicationIdentifier(hexDigits: "A0000000") == nil)
    // Seventeen bytes: above the maximum.
    let seventeenBytes = String(repeating: "AB", count: 17)
    #expect(ApplicationIdentifier(hexDigits: seventeenBytes) == nil)
    // Odd number of hex digits.
    #expect(ApplicationIdentifier(hexDigits: "A00000006") == nil)
    #expect(ApplicationIdentifier(hexDigits: "") == nil)
  }

  @Test
  internal func refusesNonHexInput() {
    #expect(ApplicationIdentifier(hexDigits: "A0000000635G") == nil)
    #expect(ApplicationIdentifier(hexDigits: "A0 00 00 00 63") == nil)
  }

  @Test
  internal func acceptsBoundaryLengths() {
    let fiveBytes = String(repeating: "A0", count: 5)
    let sixteenBytes = String(repeating: "A0", count: 16)
    #expect(ApplicationIdentifier(hexDigits: fiveBytes) != nil)
    #expect(ApplicationIdentifier(hexDigits: sixteenBytes) != nil)
  }
}
