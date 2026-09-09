// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct CardTransportSelectionTests {
  @Test
  internal func refusesEmptySelection() {
    #expect(CardTransportSelection(enabled: []) == nil)
  }

  @Test
  internal func defaultPermitsReaderOnly() {
    #expect(CardTransportSelection.readerOnly.permits(.reader))
    #expect(!CardTransportSelection.readerOnly.permits(.nearField))
  }

  @Test
  internal func allPermitsEveryTransport() {
    for transport in CardTransport.allCases {
      #expect(CardTransportSelection.all.permits(transport))
    }
  }

  @Test
  internal func disablingTheLastTransportIsRefused() {
    #expect(CardTransportSelection.readerOnly.disabling(.reader) == nil)
  }

  @Test
  internal func disablingOneOfTwoKeepsTheOther() throws {
    let remaining = try #require(CardTransportSelection.all.disabling(.nearField))
    #expect(remaining == .readerOnly)
  }

  @Test
  internal func enablingIsIdempotent() {
    #expect(CardTransportSelection.readerOnly.enabling(.reader) == .readerOnly)
    #expect(CardTransportSelection.readerOnly.enabling(.nearField) == .all)
  }

  @Test
  internal func clampingDropsUnsupportedTransports() throws {
    let nearFieldOnly = try #require(CardTransportSelection(enabled: [.nearField]))
    #expect(nearFieldOnly.clamped(to: .readerOnly) == .readerOnly)
    #expect(CardTransportSelection.all.clamped(to: .readerOnly) == .readerOnly)
  }

  @Test
  internal func clampingNeverEmptiesTheSelection() throws {
    let nearFieldOnly = try #require(CardTransportSelection(enabled: [.nearField]))
    #expect(!nearFieldOnly.clamped(to: .readerOnly).enabled.isEmpty)
  }

  @Test
  internal func rawValuesArePersistedIdentifiers() {
    #expect(CardTransport.nearField.rawValue == "near-field")
    #expect(CardTransport.reader.rawValue == "reader")
  }
}
