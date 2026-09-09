// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// Names cards from their answers to reset.
///
/// Every vector below is a real answer to reset. The documented ones are
/// from DVV's *Technology note - ATR/ATS bytes* v1.0 of 12.8.2024; the
/// two marked as measured were read from an ACS ACR1581U on 2026-07-27,
/// one per interface of the same card.
///
/// The point of the last group is the one that matters: the measured
/// card is not in the note, and the code must say so instead of naming
/// the nearest row.
@Suite
internal struct CardTypeIdentificationTests {
  /// Documented, contact interface: Thales MultiApp v5.0.
  private static let thalesContact = Data([
    0x3B, 0x7F, 0x96, 0x00, 0x00, 0x80, 0x31, 0xB8, 0x65, 0xB0, 0x85, 0x05,
    0x00, 0x11, 0x12, 0x24, 0x60, 0x82, 0x90, 0x00,
  ])

  /// Documented, contact interface: Gemalto MultiApp v4.2.
  private static let gemaltoContact = Data([
    0x3B, 0x7F, 0x96, 0x00, 0x00, 0x80, 0x31, 0xB8, 0x65, 0xB0, 0x85, 0x04,
    0x02, 0x1B, 0x12, 0x00, 0xF6, 0x82, 0x90, 0x00,
  ])

  /// Documented, contact interface: Idemia ID.me, whose header carries
  /// an `80` byte of its own -- the case that breaks a search for the
  /// category byte.
  private static let idemiaContact = Data([
    0x3B, 0xDD, 0x96, 0x00, 0x80, 0x31, 0xFE, 0x45, 0x00, 0x31, 0xB8, 0x64,
    0x04, 0x29, 0xEC, 0xC1, 0x73, 0x94, 0x01, 0x80, 0x82, 0x48,
  ])

  /// Measured, contact interface: a MultiApp v5 the note does not list.
  private static let measuredContact = Data([
    0x3B, 0x7F, 0x96, 0x00, 0x00, 0x80, 0x31, 0xB8, 0x65, 0xB0, 0x85, 0x05,
    0x10, 0x24, 0x12, 0x24, 0x60, 0x82, 0x90, 0x00,
  ])

  /// Measured, contactless interface of that same card, as a PC/SC
  /// reader synthesizes it: different framing, same card.
  private static let measuredContactless = Data([
    0x3B, 0x8F, 0x80, 0x01, 0x80, 0x31, 0xB8, 0x65, 0xB0, 0x85, 0x05, 0x10,
    0x24, 0x12, 0x24, 0x60, 0x82, 0x90, 0x00, 0x22,
  ])

  @Test
  internal func documentedCardsAreNamedExactly() throws {
    let thales = try #require(
      CardTypeIdentification.identify(answerToReset: Self.thalesContact))
    #expect(thales.name == "Thales MultiApp v5.0 (FINEID S4-1 v4.0)")
    #expect(thales.confidence == .documented)

    let gemalto = try #require(
      CardTypeIdentification.identify(answerToReset: Self.gemaltoContact))
    #expect(gemalto.name == "Gemalto MultiApp v4.2 (FINEID S4-1 v3.1)")
    #expect(gemalto.confidence == .documented)
  }

  /// The header of this card contains `80` before the historical bytes
  /// begin, so a parser that searches for it reads from the wrong offset
  /// and names the wrong card, or none.
  @Test
  internal func aHeaderContainingTheCategoryByteIsStillParsed() throws {
    let identified = try #require(
      CardTypeIdentification.identify(answerToReset: Self.idemiaContact))
    #expect(identified.name == "Idemia ID.me IDeal Citiz 2.17-i (FINEID S1 v4.0)")
    #expect(identified.confidence == .documented)
  }

  /// An undocumented variant is named by its generation.
  ///
  /// The card in the reader is a v5 whose version bytes are not the
  /// documented ones. It must be named as its generation and marked as
  /// such -- never rounded to the v5.0 row it nearly matches.
  @Test
  internal func anUndocumentedVariantIsNamedByGenerationOnly() throws {
    let identified = try #require(
      CardTypeIdentification.identify(answerToReset: Self.measuredContact))
    #expect(identified.name == "Thales MultiApp v5")
    #expect(identified.confidence == .generationOnly)
  }

  /// Both interfaces of one card carry the same historical bytes inside
  /// different framing, so both must identify identically.
  @Test
  internal func bothInterfacesOfOneCardAgree() throws {
    let contact = try #require(
      CardTypeIdentification.identify(answerToReset: Self.measuredContact))
    let contactless = try #require(
      CardTypeIdentification.identify(answerToReset: Self.measuredContactless))
    #expect(contact == contactless)
  }

  @Test
  internal func nonsenseIsNotNamed() {
    #expect(CardTypeIdentification.identify(answerToReset: Data()) == nil)
    #expect(CardTypeIdentification.identify(answerToReset: Data([0x3B])) == nil)
    // Well-formed, but no card here answers this.
    #expect(
      CardTypeIdentification.identify(
        answerToReset: Data([0x3B, 0x02, 0xAA, 0xBB])) == nil)
  }
}
