// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Extracts a card access number from the ICAO Secure Messaging Barcode
/// formats printed on Finnish identity cards issued since March 2023.
///
/// The front-side QR code contains only the CAN in the `SMB1.V3` form.
/// The reverse-side QR code contains a 90-character TD1 MRZ followed by
/// the CAN in the `SMB1.V2` form. Loose digit strings are never accepted.
public enum SecureMessagingBarcode {
  /// The exact prefix of the front-side CAN-only QR payload.
  private static let canOnlyPrefix = Data("SMB1.V3/CAN:".utf8)

  /// The exact prefix of the reverse-side MRZ-and-CAN QR payload.
  private static let mrzPrefix = Data("SMB1.V2/MRZ:".utf8)

  /// The separator before the CAN in the reverse-side payload.
  private static let canSeparator = Data("/CAN:".utf8)

  /// A TD1 MRZ is three lines of 30 characters, concatenated.
  private static let td1MrzLength = 90

  /// Start of the three-letter issuing-state field in a TD1 MRZ.
  private static let issuingStateOffset = 2

  /// The issuing-state code used by Finnish identity cards.
  private static let finnishIssuingState = Data("FIN".utf8)

  /// ASCII "0".
  private static let asciiDigitMinimum: UInt8 = 48

  /// ASCII "9".
  private static let asciiDigitMaximum: UInt8 = 57

  /// ASCII "A".
  private static let asciiUppercaseMinimum: UInt8 = 65

  /// ASCII "Z".
  private static let asciiUppercaseMaximum: UInt8 = 90

  /// ASCII space, used in the barcode in place of the MRZ filler.
  private static let asciiSpace: UInt8 = 32

  /// Returns the six CAN digits from a supported QR payload.
  ///
  /// The returned value is sensitive and must not be logged. It remains a
  /// string only long enough for the app to place it into the existing
  /// credential-entry flow, which validates it again before storage.
  public static func cardAccessNumberDigits(in payload: String) -> String? {
    let bytes = Data(payload.utf8)
    if let digits = canOnlyDigits(in: bytes) {
      return digits
    }
    return mrzAndCanDigits(in: bytes)
  }

  /// Parses the exact CAN-only payload.
  private static func canOnlyDigits(in bytes: Data) -> String? {
    guard bytes.starts(with: Self.canOnlyPrefix) else { return nil }
    return validatedDigits(
      Data(bytes.dropFirst(Self.canOnlyPrefix.count))
    )
  }

  /// Parses the exact TD1-MRZ-and-CAN payload.
  private static func mrzAndCanDigits(in bytes: Data) -> String? {
    guard bytes.starts(with: Self.mrzPrefix) else { return nil }
    let body = Data(bytes.dropFirst(Self.mrzPrefix.count))
    let expectedLength =
      Self.td1MrzLength + Self.canSeparator.count
      + CardAccessNumber.digitCount
    guard body.count == expectedLength else { return nil }

    let mrz = Data(body.prefix(Self.td1MrzLength))
    guard isFinnishTd1Mrz(mrz) else { return nil }

    let separatorStart = Self.td1MrzLength
    let separatorEnd = separatorStart + Self.canSeparator.count
    guard
      body.subdata(in: separatorStart..<separatorEnd) == Self.canSeparator
    else {
      return nil
    }
    return validatedDigits(Data(body.dropFirst(separatorEnd)))
  }

  /// Checks the fixed TD1 layout and the Finnish issuing-state field.
  private static func isFinnishTd1Mrz(_ bytes: Data) -> Bool {
    guard bytes.count == Self.td1MrzLength else { return false }
    let issuingStateEnd =
      Self.issuingStateOffset + Self.finnishIssuingState.count
    guard
      bytes.subdata(in: Self.issuingStateOffset..<issuingStateEnd)
        == Self.finnishIssuingState
    else {
      return false
    }
    return bytes.allSatisfy { byte in
      byte == Self.asciiSpace
        || byte >= Self.asciiDigitMinimum
          && byte <= Self.asciiDigitMaximum
        || byte >= Self.asciiUppercaseMinimum
          && byte <= Self.asciiUppercaseMaximum
    }
  }

  /// Accepts exactly six ASCII digits and validates the domain value.
  private static func validatedDigits(_ bytes: Data) -> String? {
    guard
      bytes.count == CardAccessNumber.digitCount,
      bytes.allSatisfy({ byte in
        byte >= Self.asciiDigitMinimum && byte <= Self.asciiDigitMaximum
      }),
      let digits = String(bytes: bytes, encoding: .ascii),
      CardAccessNumber(digits: digits) != nil
    else {
      return nil
    }
    return digits
  }
}
