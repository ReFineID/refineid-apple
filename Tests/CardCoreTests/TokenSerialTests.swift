// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct TokenSerialTests {
  @Test
  internal func refusesEmpty() {
    #expect(TokenSerial(value: "") == nil)
  }

  @Test
  internal func refusesOversized() {
    let oversized = String(
      repeating: "A",
      count: TokenSerial.maximumLength + 1
    )
    #expect(TokenSerial(value: oversized) == nil)
  }

  @Test
  internal func acceptsMaximumLength() {
    let maximal = String(repeating: "9", count: TokenSerial.maximumLength)
    #expect(TokenSerial(value: maximal) != nil)
  }

  @Test
  internal func refusesNonPrintableAndSpaces() {
    #expect(TokenSerial(value: "ABC 123") == nil)
    #expect(TokenSerial(value: "ABC\n123") == nil)
    #expect(TokenSerial(value: "sarja\u{0000}") == nil)
    #expect(TokenSerial(value: "sarjanumero-ä") == nil)
  }

  @Test
  internal func distinctSerialsDiffer() throws {
    let first = try #require(TokenSerial(value: "9990000001"))
    let second = try #require(TokenSerial(value: "9990000002"))
    #expect(first != second)
  }
}
