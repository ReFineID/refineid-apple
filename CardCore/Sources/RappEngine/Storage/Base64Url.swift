// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The unpadded base64url encoding of RFC 4648 section 5.
///
/// Deliberately separate from CardCore's JOSE `Base64Url`: this one
/// implements the RAPP offer encoding, is pinned by the vendored
/// conformance corpus, and refuses padding, a remainder-one length, and
/// any byte outside the alphabet.
///
/// Three plain bytes carry twenty-four bits, which the encoding splits into
/// four characters of six bits each. A final group of one or two bytes
/// produces two or three characters and no padding.
///
/// Because a character carries six bits and a byte eight, the boundaries
/// between them fall two, four, and six bits into a byte, which is why the
/// shifts and masks below come in exactly those three widths.
private enum Base64Url {
  /// Plain bytes consumed by one complete group.
  static let bytesPerGroup = 3
  /// Characters produced by one complete group.
  static let charactersPerGroup = 4

  /// Distances from the first byte of a group to its later bytes.
  static let secondByteOffset = 1
  static let thirdByteOffset = 2

  /// Distances from the first character of a group to its later characters.
  static let secondCharacterOffset = 1
  static let thirdCharacterOffset = 2
  static let fourthCharacterOffset = 3

  /// A group holding more than this many bytes yields a third character.
  static let bytesBeforeThirdCharacter = 2
  /// A group holding more than this many characters yields a second byte.
  static let charactersBeforeSecondByte = 2
  /// A group holding more than this many characters yields a third byte.
  static let charactersBeforeThirdByte = 3

  /// A trailing group of one character carries too few bits to decode.
  static let undecodableRemainder = 1

  /// Shift widths at the three byte-and-character boundaries.
  static let twoBits: UInt8 = 2
  static let fourBits: UInt8 = 4
  static let sixBits: UInt8 = 6

  /// Masks selecting the bits a byte contributes to the following character.
  static let lowestTwoBits: UInt8 = 0b0000_0011
  static let lowestFourBits: UInt8 = 0b0000_1111
  static let lowestSixBits: UInt8 = 0b0011_1111

  /// Values the alphabet assigns to the first character of each run.
  static let lowercaseFirstValue: UInt8 = 26
  static let digitFirstValue: UInt8 = 52
  static let dashValue: UInt8 = 62
  static let underscoreValue: UInt8 = 63

  /// The alphabet in value order, so a value indexes its own character.
  static let alphabet: [Character] = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

  /// Characters an encoding of this many bytes occupies, rounded up.
  static func characterCount(forByteCount count: Int) -> Int {
    (count * charactersPerGroup + bytesPerGroup - 1) / bytesPerGroup
  }

  /// Bytes a decoding of this many characters occupies, rounded down.
  static func byteCount(forCharacterCount count: Int) -> Int {
    count * bytesPerGroup / charactersPerGroup
  }
}

internal func base64UrlEncode(_ bytes: Data) -> String {
  var output = String()
  output.reserveCapacity(Base64Url.characterCount(forByteCount: bytes.count))
  var index = bytes.startIndex
  while index < bytes.endIndex {
    let remaining = bytes.distance(from: index, to: bytes.endIndex)
    let first = bytes[index]
    let second =
      remaining > Base64Url.secondByteOffset
      ? bytes[bytes.index(index, offsetBy: Base64Url.secondByteOffset)] : 0
    let third =
      remaining > Base64Url.bytesBeforeThirdCharacter
      ? bytes[bytes.index(index, offsetBy: Base64Url.thirdByteOffset)] : 0
    output.append(Base64Url.alphabet[Int(first >> Base64Url.twoBits)])
    output.append(
      Base64Url.alphabet[
        Int(
          (first & Base64Url.lowestTwoBits) << Base64Url.fourBits
            | second >> Base64Url.fourBits)])
    if remaining > Base64Url.secondByteOffset {
      output.append(
        Base64Url.alphabet[
          Int(
            (second & Base64Url.lowestFourBits) << Base64Url.twoBits
              | third >> Base64Url.sixBits)])
    }
    if remaining > Base64Url.bytesBeforeThirdCharacter {
      output.append(Base64Url.alphabet[Int(third & Base64Url.lowestSixBits)])
    }
    index = bytes.index(index, offsetBy: min(Base64Url.bytesPerGroup, remaining))
  }
  return output
}

internal func base64UrlDecode(_ text: String) throws -> Data {
  guard !text.isEmpty, !text.contains("="),
    text.utf8.count % Base64Url.charactersPerGroup != Base64Url.undecodableRemainder
  else {
    throw PairingOfferError.invalidBase64Url
  }
  let values = try text.utf8.map(decodeBase64UrlByte)
  var output: [UInt8] = []
  output.reserveCapacity(Base64Url.byteCount(forCharacterCount: values.count))
  var index = 0
  while index < values.count {
    let remaining = values.count - index
    let first = values[index]
    let second = values[index + Base64Url.secondCharacterOffset]
    output.append(first << Base64Url.twoBits | second >> Base64Url.fourBits)
    if remaining > Base64Url.charactersBeforeSecondByte {
      let third = values[index + Base64Url.thirdCharacterOffset]
      output.append(second << Base64Url.fourBits | third >> Base64Url.twoBits)
      if remaining > Base64Url.charactersBeforeThirdByte {
        output.append(
          third << Base64Url.sixBits
            | values[index + Base64Url.fourthCharacterOffset])
      }
    }
    index += min(Base64Url.charactersPerGroup, remaining)
  }
  return Data(output)
}

internal func decodeBase64UrlByte(_ byte: UInt8) throws -> UInt8 {
  switch byte {
  case UInt8(ascii: "A")...UInt8(ascii: "Z"):
    return byte - UInt8(ascii: "A")

  case UInt8(ascii: "a")...UInt8(ascii: "z"):
    return byte - UInt8(ascii: "a") + Base64Url.lowercaseFirstValue

  case UInt8(ascii: "0")...UInt8(ascii: "9"):
    return byte - UInt8(ascii: "0") + Base64Url.digitFirstValue

  case UInt8(ascii: "-"):
    return Base64Url.dashValue

  case UInt8(ascii: "_"):
    return Base64Url.underscoreValue

  default:
    throw PairingOfferError.invalidBase64Url
  }
}
