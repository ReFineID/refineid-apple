// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The offline gate for PACE.
///
/// `SyntheticPaceCard` plays the card half of the protocol with its own
/// nonce, its own two ephemeral scalars, and its own key derivation. Both
/// sides therefore reach Kenc and Kmac by independent routes, and if the two
/// results agree the whole exchange agreed: the nonce decryption, the
/// generic mapping, the key agreement on the mapped generator, and the two
/// authentication token encodings. Nothing here touches hardware, and the
/// deterministic scalar source is what makes the run reproducible.
@Suite
internal struct PaceEstablishmentTests {
  /// The card access number these runs use.
  ///
  /// Fictitious, like every other secret in this file.
  private static let accessNumberDigits = "123456"

  /// A different, equally fictitious CAN, for the wrong-CAN run.
  private static let wrongAccessNumberDigits = "654321"

  /// The card's PACE nonce: one AES block.
  private static let nonceHex = "000102030405060708090A0B0C0D0E0F"

  /// Sixteen-byte building blocks for the four fixed scalars.
  ///
  /// Each block's leading byte is well below `8C`, the leading byte of the
  /// group order, so every scalar assembled from three of them lies in
  /// `[1, n)` without a reduction.
  private static let firstBlockHex = "0F1E2D3C4B5A69788796A5B4C3D2E1F0"

  private static let secondBlockHex = "1A2B3C4D5E6F708192A3B4C5D6E7F809"

  private static let thirdBlockHex = "2C3D4E5F60718293A4B5C6D7E8F90A1B"

  private static let fourthBlockHex = "3D4E5F60718293A4B5C6D7E8F90A1B2C"

  /// The synthetic card, holding the CAN it expects and its fixed secrets.
  private static func card(accessNumberDigits: String) throws -> SyntheticPaceCard {
    SyntheticPaceCard(
      accessNumberDigits: accessNumberDigits,
      nonce: WireHex.data(Self.nonceHex),
      mappingScalar: try Self.scalar(
        Self.thirdBlockHex + Self.fourthBlockHex + Self.firstBlockHex
      ),
      agreementScalar: try Self.scalar(
        Self.fourthBlockHex + Self.firstBlockHex + Self.secondBlockHex
      )
    )
  }

  /// The terminal's two fixed scalars, handed out in protocol order.
  private static func terminalScalars() throws -> PaceEphemeralScalarSource {
    let scalars = [
      try Self.scalar(Self.firstBlockHex + Self.secondBlockHex + Self.thirdBlockHex),
      try Self.scalar(Self.secondBlockHex + Self.thirdBlockHex + Self.fourthBlockHex),
    ]
    var index = 0
    return PaceEphemeralScalarSource {
      let value = scalars[min(index, scalars.count - 1)]
      index += 1
      return value
    }
  }

  /// A 384-bit scalar from its big-endian hex.
  private static func scalar(_ hexDigits: String) throws -> U384 {
    try #require(U384(bigEndianBytes: WireHex.data(hexDigits)))
  }

  @Test
  internal func terminalAndCardDeriveTheSameSessionKeys() throws {
    let accessNumber = try #require(CardAccessNumber(digits: Self.accessNumberDigits))
    let card = try Self.card(accessNumberDigits: Self.accessNumberDigits)

    let session = try PaceEstablishment(
      channel: card,
      scalarSource: try Self.terminalScalars()
    )
    .establish(with: accessNumber)

    let cardKeys = try #require(card.sessionKeys)
    #expect(session == cardKeys)
  }

  @Test
  internal func aWrongCardAccessNumberFailsMutualAuthentication() throws {
    let accessNumber = try #require(CardAccessNumber(digits: Self.wrongAccessNumberDigits))
    let card = try Self.card(accessNumberDigits: Self.accessNumberDigits)

    // The card never signals the wrong CAN directly; a wrong password key
    // yields a wrong nonce, a different mapped generator, and therefore a
    // token the card refuses three rounds later.
    #expect(throws: (any Error).self) {
      try PaceEstablishment(
        channel: card,
        scalarSource: try Self.terminalScalars()
      )
      .establish(with: accessNumber)
    }
    #expect(card.sessionKeys != nil)
  }

  @Test
  internal func aCardAccessNumberIsExactlySixDigits() {
    #expect(CardAccessNumber(digits: "12345") == nil)
    #expect(CardAccessNumber(digits: "1234567") == nil)
    #expect(CardAccessNumber(digits: "12345A") == nil)
    #expect(CardAccessNumber(digits: "") == nil)
    #expect(CardAccessNumber(digits: Self.accessNumberDigits) != nil)
  }
}
