// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Exercises the secure-messaging decorator against a synthetic card that
/// computes the same MACs from the same rules with its own counter.
///
/// The properties checked here are the ones whose failure is silent on
/// hardware: a counter that drifts by one produces MAC failures on every
/// later command with nothing pointing at the cause, and the case that
/// causes the drift - an error status word arriving with a protected body -
/// is the ordinary end of every file read.
@Suite
internal struct SecureMessagingChannelTests {
  /// An arbitrary AES-256 Kenc for these exchanges.
  private static let encryptionKeyHex = """
    000102030405060708090A0B0C0D0E0F\
    101112131415161718191A1B1C1D1E1F
    """

  /// An arbitrary AES-256 Kmac, distinct from Kenc.
  private static let macKeyHex = """
    202122232425262728292A2B2C2D2E2F\
    303132333435363738393A3B3C3D3E3F
    """

  /// SELECT EF 5031, a plain command with a data field and no Le.
  private static let selectObjectDirectoryHex = "00A4020C025031"

  /// READ BINARY at offset zero with Le, a plain command with no data.
  private static let readBinaryHex = "00B0000010"

  /// The same SELECT with the secure-messaging class bits set.
  private static let protectedSelectHeaderHex = "0CA4020C"

  /// Normal processing.
  private static let successHex = "9000"

  /// End of file reached before Le bytes: the error that still arrives
  /// with a protected body.
  private static let endOfFileHex = "6282"

  /// One whole AES block of payload, to exercise the padding rule that an
  /// already-aligned buffer gains an entire extra block.
  private static let blockAlignedHex = "000102030405060708090A0B0C0D0E0F"

  /// A payload that is not block aligned.
  private static let unalignedHex = "A1B2C3"

  /// The counter values a card sees on the first and second command when
  /// the terminal increments in both directions.
  private static let firstCommandCounterHex = """
    00000000000000000000000000000001
    """

  private static let secondCommandCounterHex = """
    00000000000000000000000000000003
    """

  /// A synthetic card holding the suite's keys.
  private static func card(
    responses: [(payload: Data, statusWord: Data)],
    fault: SecureMessagingMirrorCard.Fault = .honest
  ) -> SecureMessagingMirrorCard {
    SecureMessagingMirrorCard(
      encryptionKey: WireHex.data(Self.encryptionKeyHex),
      macKey: WireHex.data(Self.macKeyHex),
      responses: responses,
      fault: fault
    )
  }

  /// The channel under test, over the suite's keys.
  private static func channel(over card: SecureMessagingMirrorCard) throws
    -> SecureMessagingChannel
  {
    let keys = try #require(
      PaceSessionKeys(
        encryptionKey: WireHex.data(Self.encryptionKeyHex),
        macKey: WireHex.data(Self.macKeyHex)
      )
    )
    return SecureMessagingChannel(wrapping: card, sessionKeys: keys)
  }

  @Test
  internal func wrappingSetsTheSecureMessagingClassBit() throws {
    let card = Self.card(responses: [(Data(), WireHex.data(Self.successHex))])
    let channel = try Self.channel(over: card)

    let response = try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))

    #expect(response == WireHex.data(Self.successHex))
    #expect(card.receivedHeaders == [WireHex.data(Self.protectedSelectHeaderHex)])
    #expect(card.recoveredCommandData == [WireHex.data("5031")])
  }

  /// RSA-2048's exact 256-byte Le survives secure messaging as DO'97'=00
  /// and reaches the structured CryptoTokenKit continuation path.
  @Test
  internal func rsa2048MaximumLeComposesWithProtectedTransport() throws {
    let card = Self.card(responses: [(Data(), WireHex.data(Self.successHex))])
    let channel = try Self.channel(over: card)
    let exact = try #require(
      CardKeyProfile.rsa2048.expectedSignatureLength
    )
    let command = CommandApdu.computeSignatureOverLoadedHash(
      exactLength: exact
    )

    let response = try channel.transmit(command.encoded)

    #expect(response == WireHex.data(Self.successHex))
    #expect(card.receivedExpectedLengths == [0])
    #expect(card.receivedCommands.count == 1)
    let protected = try #require(card.receivedCommands.first)
    let structured = try #require(
      CommandApdu.structuredProtectedSignature(protected)
    )
    #expect(structured.expectedLength == 0)
    #expect(structured.ins == 0x2A)
    #expect(structured.parameter1 == 0x9E)
    #expect(structured.parameter2 == 0x9A)
  }

  @Test
  internal func sendSequenceCounterAdvancesOnBothDirections() throws {
    let card = Self.card(responses: [
      (Data(), WireHex.data(Self.successHex)),
      (WireHex.data(Self.unalignedHex), WireHex.data(Self.successHex)),
    ])
    let channel = try Self.channel(over: card)

    _ = try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))
    let second = try channel.transmit(WireHex.data(Self.readBinaryHex))

    // The card verified the second command with counter 3, not 2: the
    // response leg consumed one value on both sides.
    #expect(
      card.commandCounters == [
        WireHex.data(Self.firstCommandCounterHex),
        WireHex.data(Self.secondCommandCounterHex),
      ]
    )
    #expect(second == WireHex.data(Self.unalignedHex + Self.successHex))
  }

  @Test
  internal func aWrongMacIsRejected() throws {
    let card = Self.card(
      responses: [(WireHex.data(Self.unalignedHex), WireHex.data(Self.successHex))],
      fault: .tamperedMac
    )
    let channel = try Self.channel(over: card)

    #expect(throws: SecureMessagingChannel.Failure.macMismatch) {
      try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))
    }
  }

  /// Once one protected exchange has failed, the counter cannot be
  /// trusted to match the card's, so the channel refuses every later
  /// exchange up front instead of failing its MAC unpredictably.
  @Test
  internal func aFailedExchangeFailStopsTheChannel() throws {
    let card = Self.card(
      responses: [
        (WireHex.data(Self.unalignedHex), WireHex.data(Self.successHex)),
        (Data(), WireHex.data(Self.successHex)),
      ],
      fault: .tamperedMac
    )
    let channel = try Self.channel(over: card)

    #expect(throws: SecureMessagingChannel.Failure.macMismatch) {
      try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))
    }
    #expect(throws: SecureMessagingChannel.Failure.desynchronized) {
      try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))
    }
    #expect(card.receivedHeaders.count == 1)
  }

  @Test
  internal func paddingRoundTripsForAlignedAndUnalignedBodies() throws {
    let card = Self.card(responses: [
      (WireHex.data(Self.blockAlignedHex), WireHex.data(Self.successHex)),
      (WireHex.data(Self.unalignedHex), WireHex.data(Self.successHex)),
    ])
    let channel = try Self.channel(over: card)

    let aligned = try channel.transmit(
      WireHex.data("00A4020C10" + Self.blockAlignedHex)
    )
    let unaligned = try channel.transmit(
      WireHex.data("00A4020C03" + Self.unalignedHex)
    )

    #expect(aligned == WireHex.data(Self.blockAlignedHex + Self.successHex))
    #expect(unaligned == WireHex.data(Self.unalignedHex + Self.successHex))
    #expect(
      card.recoveredCommandData == [
        WireHex.data(Self.blockAlignedHex),
        WireHex.data(Self.unalignedHex),
      ]
    )
  }

  @Test
  internal func errorStatusWithAProtectedBodyStillUnwrapsAndAdvances() throws {
    // A card at end of file answers 6282 at the OUTER level while still
    // protecting the response - and it has already incremented its own
    // counter to produce that DO'8E'. If the channel returned early on the
    // outer error, the second command below would fail the card's MAC.
    let card = Self.card(responses: [
      (WireHex.data(Self.unalignedHex), WireHex.data(Self.endOfFileHex)),
      (Data(), WireHex.data(Self.successHex)),
    ])
    let channel = try Self.channel(over: card)

    let first = try channel.transmit(WireHex.data(Self.readBinaryHex))
    let second = try channel.transmit(WireHex.data(Self.selectObjectDirectoryHex))

    #expect(first == WireHex.data(Self.unalignedHex + Self.endOfFileHex))
    #expect(second == WireHex.data(Self.successHex))
    #expect(
      card.commandCounters == [
        WireHex.data(Self.firstCommandCounterHex),
        WireHex.data(Self.secondCommandCounterHex),
      ]
    )
  }
}
