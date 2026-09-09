// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

@Suite("Deterministic CBOR controls the storage codecs rely on")
internal struct DeterministicCBORControlTests {
  @Test("A non-minimal integer encoding is rejected")
  internal func nonMinimalIntegerIsRejected() {
    #expect(throws: (any Error).self) { _ = try decodeDeterministicCbor(Data([0x18, 0x01])) }
  }

  @Test("An indefinite-length item is rejected")
  internal func indefiniteLengthIsRejected() {
    #expect(throws: (any Error).self) { _ = try decodeDeterministicCbor(Data([0x5f, 0xff])) }
  }

  @Test("A duplicate map key is rejected")
  internal func duplicateMapKeyIsRejected() {
    #expect(throws: (any Error).self) {
      _ = try decodeDeterministicCbor(Data([0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02]))
    }
  }

  @Test("A non-text map key is rejected")
  internal func nonTextMapKeyIsRejected() {
    #expect(throws: (any Error).self) {
      _ = try decodeDeterministicCbor(Data([0xa1, 0x01, 0x01]))
    }
  }

  @Test("Out-of-order map keys are rejected as non-canonical")
  internal func outOfOrderMapKeysAreRejected() {
    #expect(throws: (any Error).self) {
      _ = try decodeDeterministicCbor(Data([0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02]))
    }
  }

  @Test("Trailing data is rejected")
  internal func trailingDataIsRejected() {
    #expect(throws: (any Error).self) { _ = try decodeDeterministicCbor(Data([0x01, 0x01])) }
  }

  @Test("Truncated input is rejected")
  internal func truncatedInputIsRejected() {
    #expect(throws: (any Error).self) { _ = try decodeDeterministicCbor(Data([0x42, 0x01])) }
  }

  @Test("Canonical map ordering is by key length then bytes")
  internal func canonicalMapOrderingIsLengthThenBytes() throws {
    let encoded = try WireValue.map(["bb": .unsigned(2), "a": .unsigned(1)]).encoded()
    #expect(encoded == Data([0xa2, 0x61, 0x61, 0x01, 0x62, 0x62, 0x62, 0x02]))
  }
}
