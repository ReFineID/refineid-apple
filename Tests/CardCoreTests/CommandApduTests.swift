// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct CommandApduTests {
  @Test
  internal func selectFineidApplicationMatchesTheWireVector() {
    // FINEID S1 v4.2: SELECT by AID, no FCI. Header 00 A4 04 0C,
    // Lc 0C, then the DVV-documented AID.
    let command = CommandApdu.selectApplication(.fineidApplication)
    #expect(
      command.encoded == WireHex.data("00A4040C0CA000000063504B43532D3135")
    )
  }

  @Test
  internal func retryCounterProbesForEveryRole() {
    // FINEID S1 v4.2 §3.5.1.1: VERIFY with Lc=00 probes the counter
    // without consuming an attempt. P2 selects the credential.
    #expect(
      CommandApdu.readRetryCounter(role: .pin1, references: .citizen).encoded
        == WireHex.data("0020001100")
    )
    #expect(
      CommandApdu.readRetryCounter(role: .pin2, references: .citizen).encoded
        == WireHex.data("0020008200")
    )
    #expect(
      CommandApdu.readRetryCounter(role: .puk, references: .citizen).encoded
        == WireHex.data("0020008300")
    )
  }

  @Test
  internal func retryCounterProbesTheOrganizationNumbering() {
    // FINEID S4-2 v4.0 §4.2: PIN AUTH 03, PIN SIG 04, PIN PUK 12.
    #expect(
      CommandApdu.readRetryCounter(role: .pin1, references: .organization).encoded
        == WireHex.data("0020000300")
    )
    #expect(
      CommandApdu.readRetryCounter(role: .pin2, references: .organization).encoded
        == WireHex.data("0020000400")
    )
    #expect(
      CommandApdu.readRetryCounter(role: .puk, references: .organization).encoded
        == WireHex.data("0020001200")
    )
  }

  @Test
  internal func selectElementaryFileMatchesTheWireVector() {
    // FINEID S1 v4.2 §3.2.2: select EF under the current DF, no
    // response data. EF.TokenInfo is 5032, EF.ODF is 5031.
    #expect(
      CommandApdu.selectElementaryFile(.tokenInfo).encoded
        == WireHex.data("00A4020C025032")
    )
    #expect(
      CommandApdu.selectElementaryFile(.objectDirectory).encoded
        == WireHex.data("00A4020C025031")
    )
  }

  @Test
  internal func getResponseEncodesTheAnnouncedCount() {
    #expect(
      CommandApdu.getResponse(announcedCount: 37).encoded
        == WireHex.data("00C0000025")
    )
    // Zero announces 256 or more; Le 00 requests the maximum.
    #expect(
      CommandApdu.getResponse(announcedCount: 0).encoded
        == WireHex.data("00C0000000")
    )
  }

  @Test
  internal func readBinaryEncodesOffsetAndLength() throws {
    let start = try #require(ReadOffset(value: 0))
    let deep = try #require(ReadOffset(value: 4_660))
    let sixteen = try #require(ExpectedResponseLength(count: 16))
    let maximum = try #require(
      ExpectedResponseLength(count: ExpectedResponseLength.maximum)
    )

    // Le 00 encodes "up to 256".
    #expect(
      CommandApdu.readBinary(offset: start, expectedLength: maximum).encoded
        == WireHex.data("00B0000000")
    )
    // Offset 4660 (hex 1234) splits across P1-P2.
    #expect(
      CommandApdu.readBinary(offset: deep, expectedLength: sixteen).encoded
        == WireHex.data("00B0123410")
    )
  }

  @Test
  internal func readOffsetRefusesAboveFifteenBits() {
    #expect(ReadOffset(value: ReadOffset.maximum) != nil)
    #expect(ReadOffset(value: ReadOffset.maximum + 1) == nil)
  }

  @Test
  internal func expectedLengthRefusesZeroAndOversize() {
    #expect(ExpectedResponseLength(count: 0) == nil)
    #expect(ExpectedResponseLength(count: 1) != nil)
    #expect(
      ExpectedResponseLength(count: ExpectedResponseLength.maximum + 1) == nil
    )
  }

  @Test
  internal func structuredSignatureAcceptsOnlyProtectedMaximumLengthPso() throws {
    // Synthetic secure-messaging body: the parser intentionally treats it
    // as opaque and only separates the short case-4 APDU framing.
    let protectedMaximum = WireHex.data(
      "0C2A9E9A0D9701008E08000102030405060700")
    let parsed = try #require(
      CommandApdu.structuredProtectedSignature(protectedMaximum))
    #expect(parsed.cla == 0x0C)
    #expect(parsed.ins == 0x2A)
    #expect(parsed.parameter1 == 0x9E)
    #expect(parsed.parameter2 == 0x9A)
    #expect(parsed.data == WireHex.data("9701008E080001020304050607"))
    #expect(parsed.expectedLength == 0)

    let exactLengthEcdsa = WireHex.data(
      "0C2A9E9A0D9701608E08000102030405060760")
    #expect(CommandApdu.structuredProtectedSignature(exactLengthEcdsa) == nil)
    #expect(
      CommandApdu.structuredProtectedSignature(
        WireHex.data("0CB000000D9701008E08000102030405060700")
      ) == nil
    )
  }

  @Test
  internal func verifyPin1MatchesTheWireVector() {
    // FINEID S1 v4.2 §3.5.2 example shape: 00 20 00 11 0C, then the
    // ASCII digits right-padded with zero bytes to twelve.
    guard let pin = Pin1(digits: "123456") else {
      Issue.record("valid PIN failed to construct")
      return
    }
    let command = CredentialBearingCommand.verifyPin1(
      pin.consumeForSingleTransmission(),
      references: .citizen
    )
    #expect(
      command.intoTransportPayload()
        == WireHex.data("002000110C313233343536000000000000")
    )
  }
}
