// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Pins the command sequence of a chunked read on both transports, and
/// the fact the contactless one depends on.
///
/// A read to end of file stops at the first chunk that comes back
/// shorter than it asked for. Over secure messaging the answer travels
/// as DO'87', DO'99' and DO'8E' inside one short-form response, so a
/// chunk the envelope could not carry whole would come back short every
/// time -- and the assembler would take the first one for the end of the
/// file and return a truncated certificate, silently, as wrong data
/// rather than as an error. These tests state what each transport asks
/// for, and prove the contactless chunk is inside what a protected
/// response can actually carry.
@Suite
internal struct SecureMessagedReadTests {
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

  /// Normal processing.
  private static let successHex = "9000"

  /// SELECT the eID application, with the secure-messaging class bits
  /// set: `0C A4 04 0C`.
  private static let protectedSelectApplicationHeaderHex = "0CA4040C"

  /// SELECT an EF under the current DF, protected: `0C A4 02 0C`.
  private static let protectedSelectFileHeaderHex = "0CA4020C"

  /// READ BINARY at offset 0, protected: `0C B0 00 00`.
  private static let protectedReadHeaderHex = "0CB00000"

  /// READ BINARY at offset 128, protected: `0C B0 00 80`.
  private static let protectedSecondReadHeaderHex = "0CB00080"

  /// READ BINARY at offset 256, protected: `0C B0 01 00`.
  private static let protectedThirdReadHeaderHex = "0CB00100"

  /// The Le of a full chunk, as it travels in DO'97': 128 bytes.
  private static let chunkExpectedLengthHex = "80"

  /// The Le of the last chunk of the certificate below: 44 bytes, the
  /// remainder the DER header's declared length leaves.
  private static let finalExpectedLengthHex = "2C"

  /// A synthetic 300-byte DER object: a SEQUENCE whose header declares
  /// 296 content bytes, so the read's cap is known from its first chunk.
  private static let certificateHex =
    "30820128" + String(repeating: "AB", count: 124)
    + String(repeating: "CD", count: 128)
    + String(repeating: "EF", count: 44)

  /// The object's total length in bytes.
  private static let certificateLength = 300

  /// A synthetic card holding the suite's keys.
  private static func card(
    responses: [(payload: Data, statusWord: Data)]
  ) -> SecureMessagingMirrorCard {
    SecureMessagingMirrorCard(
      encryptionKey: WireHex.data(Self.encryptionKeyHex),
      macKey: WireHex.data(Self.macKeyHex),
      responses: responses,
      fault: .honest
    )
  }

  /// The secure-messaging channel over the suite's keys.
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

  /// One scripted success response carrying `hex`.
  private static func success(_ hex: String) -> (payload: Data, statusWord: Data) {
    (payload: WireHex.data(hex), statusWord: WireHex.data(Self.successHex))
  }

  /// The certificate cut into the chunks a 128-byte read asks for: 128,
  /// 128, then the 44 the declared length leaves.
  private static func certificateChunkHex(index: Int) -> String {
    let digitsPerByte = 2
    let chunk = 128 * digitsPerByte
    let characters = Array(Self.certificateHex)
    let start = min(index * chunk, characters.count)
    let end = min(start + chunk, characters.count)
    return String(characters[start..<end])
  }

  @Test
  internal func contactReadAsksForTheCommandsItAlwaysHas() throws {
    // The contact path takes the default chunk length and must not move
    // a byte: 128 per READ BINARY, offsets 0, 128, 256, and a short
    // final chunk ends the read.
    let first = String(repeating: "A1", count: 128)
    let second = String(repeating: "B2", count: 128)
    let third = String(repeating: "C3", count: 44)
    let channel = ScriptedChannel([
      ("00A4020C025031", Self.successHex),
      ("00B0000080", first + Self.successHex),
      ("00B0008080", second + Self.successHex),
      ("00B0010080", third + Self.successHex),
    ])

    let read = try CardOperations(channel: channel)
      .readElementaryFile(.objectDirectory, expectedLength: nil)

    #expect(read == WireHex.data(first + second + third))
    #expect(channel.isExhausted)
  }

  @Test
  internal func secureMessagedReadAsksForTheSameLengthsInsideTheEnvelope() throws {
    // The same read over the protected transport: the enclosed commands
    // are the plain ones, with the class bits set and each Le carried in
    // DO'97'. Two full chunks, then exactly the 44 bytes the DER header
    // says are left - never a fourth command, which the card would
    // reject as an exhausted script.
    let card = Self.card(responses: [
      Self.success(""),
      Self.success(""),
      Self.success(Self.certificateChunkHex(index: 0)),
      Self.success(Self.certificateChunkHex(index: 1)),
      Self.success(Self.certificateChunkHex(index: 2)),
    ])
    let operations = CardOperations(channel: try Self.channel(over: card))

    _ = try operations.readCertificate(.authentication)

    #expect(
      card.receivedHeaders == [
        WireHex.data(Self.protectedSelectApplicationHeaderHex),
        WireHex.data(Self.protectedSelectFileHeaderHex),
        WireHex.data(Self.protectedReadHeaderHex),
        WireHex.data(Self.protectedSecondReadHeaderHex),
        WireHex.data(Self.protectedThirdReadHeaderHex),
      ]
    )
    let chunkLe = WireHex.data(Self.chunkExpectedLengthHex).first
    let finalLe = WireHex.data(Self.finalExpectedLengthHex).first
    #expect(card.receivedExpectedLengths == [nil, nil, chunkLe, chunkLe, finalLe])
  }

  @Test
  internal func multiChunkSecureMessagedCertificateAssemblesWhole() throws {
    // The bug this guards: every chunk but the last comes back full, so
    // the read runs to the DER-declared end instead of stopping at the
    // first chunk and handing back a truncated certificate. The card
    // trims any answer that does not fit one protected response, so a
    // chunk the envelope could not carry would end this read 172 bytes
    // early.
    let card = Self.card(responses: [
      Self.success(""),
      Self.success(""),
      Self.success(Self.certificateChunkHex(index: 0)),
      Self.success(Self.certificateChunkHex(index: 1)),
      Self.success(Self.certificateChunkHex(index: 2)),
    ])
    let operations = CardOperations(channel: try Self.channel(over: card))

    let read = try operations.readCertificate(.authentication)

    #expect(read == WireHex.data(Self.certificateHex))
    #expect(read.count == Self.certificateLength)
  }

  @Test
  internal func aWholeSecureMessagedChunkFitsOneProtectedResponse() throws {
    // Ask the card for far more than one protected response can hold.
    // What comes back is short - the envelope really does bite - but it
    // is still at least a whole secure-messaged chunk, which is the
    // property the read above depends on. Raise the chunk past what the
    // envelope carries and this fails.
    let asked = ExpectedResponseLength.maximum
    let overlong = Self.success(String(repeating: "5A", count: asked))
    let card = Self.card(responses: [overlong])
    let channel = try Self.channel(over: card)
    let command = CommandApdu.readBinary(
      offset: try #require(ReadOffset(value: 0)),
      expectedLength: try #require(
        ExpectedResponseLength(count: ReadChunkLength.secureMessaged.count)
      )
    )

    let response = try channel.transmit(command.encoded)

    let honoured = response.count - ResponseApdu.statusWordLength
    #expect(honoured < asked)
    #expect(honoured >= ReadChunkLength.secureMessaged.count)
  }
}
