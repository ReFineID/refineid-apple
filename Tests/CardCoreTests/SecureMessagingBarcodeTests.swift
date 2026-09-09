// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct SecureMessagingBarcodeTests {
  /// Synthetic CAN used only to exercise the parser.
  private static let accessNumber = "246801"

  /// Builds a synthetic 90-character TD1 MRZ without real card data.
  private static func syntheticTd1Mrz(
    issuingState: String = "FIN"
  ) -> String {
    let line1 =
      "I " + issuingState + "ZX0000001" + "0"
      + String(repeating: " ", count: 15)
    let line2 =
      "900101" + "1" + "X" + "300101" + "9" + "FIN"
      + String(repeating: " ", count: 11) + "0"
    let name = "SAMPLE  ALEX"
    let line3 = name + String(repeating: " ", count: 30 - name.count)
    return line1 + line2 + line3
  }

  @Test
  internal func parsesExactCanOnlyPayload() {
    let payload = "SMB1.V3/CAN:" + Self.accessNumber
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(in: payload)
        == Self.accessNumber
    )
  }

  @Test
  internal func parsesCanFromExactTd1Payload() {
    let payload =
      "SMB1.V2/MRZ:" + Self.syntheticTd1Mrz()
      + "/CAN:" + Self.accessNumber
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(in: payload)
        == Self.accessNumber
    )
  }

  @Test
  internal func rejectsPrintedDatesAndLooseNumbers() {
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(in: "900101") == nil
    )
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(
        in: "Date of birth 900101") == nil
    )
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(
        in: "SMB1.V3/CAN:246801/extra") == nil
    )
  }

  @Test
  internal func rejectsWrongVersionsAndMalformedMrz() {
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(
        in: "SMB1.V2/CAN:" + Self.accessNumber) == nil
    )
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(
        in: "SMB1.V3/MRZ:" + Self.syntheticTd1Mrz()
          + "/CAN:" + Self.accessNumber) == nil
    )

    let nonFinnishMrz = Self.syntheticTd1Mrz(issuingState: "UTO")
    #expect(
      SecureMessagingBarcode.cardAccessNumberDigits(
        in: "SMB1.V2/MRZ:" + nonFinnishMrz
          + "/CAN:" + Self.accessNumber) == nil
    )
  }
}
