// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct DerTlvRecordTests {
  /// Tag `7C`, the Dynamic Authentication Data template that wraps every
  /// GENERAL AUTHENTICATE payload.
  private static let dynamicAuthenticationDataTag: UInt8 = 0x7C

  /// Context tag `81` inside `7C`: the terminal's mapping data.
  private static let mappingDataTerminalTag: UInt8 = 0x81

  /// Secure-messaging DO'87': padding indicator plus cryptogram.
  private static let cryptogramTag: UInt8 = 0x87

  /// A value length that forces the one-octet long form (`81 C8`).
  private static let longFormValueLength = 200

  /// Filler byte for the synthetic long-form value.
  private static let fillerByte: UInt8 = 0xA5

  @Test
  internal func parsesNestedDynamicAuthenticationTemplate() throws {
    // 7C len ( 81 len <eight mapping-data bytes> )
    let wire = WireHex.data("7C0A81080011223344556677")
    let outer = try DerTlvRecord.sequence(in: wire)
    #expect(outer.count == 1)
    let template = try #require(outer.first)
    #expect(template.tag == Self.dynamicAuthenticationDataTag)

    let inner = try DerTlvRecord.sequence(in: template.value)
    #expect(inner.count == 1)
    let mappingData = try #require(inner.first)
    #expect(mappingData.tag == Self.mappingDataTerminalTag)
    #expect(mappingData.value == WireHex.data("0011223344556677"))
  }

  @Test
  internal func buildsNestedTemplateByComposition() throws {
    let inner = try #require(
      DerTlvRecord.encoded(
        tag: Self.mappingDataTerminalTag,
        value: WireHex.data("0011223344556677")
      )
    )
    let template = try #require(
      DerTlvRecord.encoded(
        tag: Self.dynamicAuthenticationDataTag,
        value: inner
      )
    )
    #expect(template == WireHex.data("7C0A81080011223344556677"))
  }

  @Test
  internal func roundTripsSecureMessagingCryptogram() throws {
    // 87 11 01 <sixteen cryptogram bytes>
    let wire = WireHex.data("871101000102030405060708090A0B0C0D0E0F")
    let records = try DerTlvRecord.sequence(in: wire)
    let cryptogram = try #require(records.first)
    #expect(cryptogram.tag == Self.cryptogramTag)
    #expect(cryptogram.encoded == wire)
    #expect(
      DerTlvRecord.encoded(tag: cryptogram.tag, value: cryptogram.value) == wire
    )
  }

  @Test
  internal func roundTripsOneOctetLongFormLength() throws {
    let value = Data(
      repeating: Self.fillerByte,
      count: Self.longFormValueLength
    )
    let wire = try #require(
      DerTlvRecord.encoded(tag: Self.cryptogramTag, value: value)
    )
    // Tag, then the one-octet long form: 81 C8 is 200 bytes.
    let header = WireHex.data("8781C8")
    #expect(wire.prefix(header.count) == header)

    let records = try DerTlvRecord.sequence(in: wire)
    let record = try #require(records.first)
    #expect(record.value == value)
  }

  @Test
  internal func rejectsTruncatedInput() {
    // A tag with no length octet at all.
    #expect(throws: DerTlvRecord.Malformed.self) {
      try DerTlvRecord.sequence(in: WireHex.data("7C"))
    }
    // A length that overruns the data.
    #expect(throws: DerTlvRecord.Malformed.self) {
      try DerTlvRecord.sequence(in: WireHex.data("7C0581"))
    }
    // A well-formed template whose inner object is truncated.
    #expect(throws: DerTlvRecord.Malformed.self) {
      let template = try DerTlvRecord.sequence(in: WireHex.data("7C03810800"))
      let inner = try #require(template.first)
      _ = try DerTlvRecord.sequence(in: inner.value)
    }
    // A long-form length octet count the reader refuses.
    #expect(throws: DerTlvRecord.Malformed.self) {
      try DerTlvRecord.sequence(in: WireHex.data("7C8400000001AA"))
    }
  }

  @Test
  internal func refusesValueLongerThanTheReaderAccepts() {
    let oversized = Data(
      repeating: Self.fillerByte,
      count: BinaryReadAssembler.maximumTotalLength + 1
    )
    #expect(
      DerTlvRecord.encoded(tag: Self.cryptogramTag, value: oversized) == nil
    )
  }
}
