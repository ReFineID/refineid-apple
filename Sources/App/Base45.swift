// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// RFC 9285 Base45, whose alphabet stays in QR alphanumeric mode.
internal enum Base45 {
  /// The alphabet in index order.
  private static let alphabet = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:".utf8
  )

  /// The radix.
  private static let radix = 45

  /// The radix squared.
  private static let radixSquared = Self.radix * Self.radix

  /// The number of values in one byte.
  private static let byteRadix = 256

  /// Bytes consumed by a complete Base45 group.
  private static let pairByteCount = 2

  /// Characters emitted by a complete Base45 group.
  private static let pairCharacterCount = 3

  /// The only character-count remainder no Base45 value can have.
  private static let invalidRemainder = 1

  /// Two bytes become three characters; one becomes two.
  internal static func encode(_ data: Data) -> String {
    let bytes = Array(data)
    var encoded = [UInt8]()
    encoded.reserveCapacity(
      (bytes.count * Self.pairCharacterCount + Self.invalidRemainder)
        / Self.pairByteCount
    )
    var index = 0
    while index + Self.invalidRemainder < bytes.count {
      let value =
        Int(bytes[index]) * Self.byteRadix
        + Int(bytes[index + Self.invalidRemainder])
      encoded.append(Self.alphabet[value % Self.radix])
      encoded.append(Self.alphabet[value / Self.radix % Self.radix])
      encoded.append(Self.alphabet[value / Self.radixSquared])
      index += Self.pairByteCount
    }
    if index < bytes.count {
      let value = Int(bytes[index])
      encoded.append(Self.alphabet[value % Self.radix])
      encoded.append(Self.alphabet[value / Self.radix])
    }
    guard let text = String(bytes: encoded, encoding: .ascii) else {
      return ""
    }
    return text
  }

  /// Decodes an RFC 9285 string, or nil for a character or value
  /// outside the encoding.
  internal static func decode(_ encoded: String) -> Data? {
    let lookup = Dictionary(
      uniqueKeysWithValues: Self.alphabet.enumerated().map { value, byte in
        (byte, value)
      }
    )
    let characters = Array(encoded.utf8)
    guard
      characters.count % Self.pairCharacterCount != Self.invalidRemainder
    else { return nil }
    var decoded = [UInt8]()
    decoded.reserveCapacity(
      characters.count * Self.pairByteCount / Self.pairCharacterCount
    )
    var index = 0
    while index + Self.pairByteCount < characters.count {
      guard
        let low = lookup[characters[index]],
        let middle = lookup[characters[index + Self.invalidRemainder]],
        let high = lookup[characters[index + Self.pairByteCount]]
      else {
        return nil
      }
      let value = low + middle * Self.radix + high * Self.radixSquared
      guard value < Self.byteRadix * Self.byteRadix else { return nil }
      decoded.append(UInt8(value / Self.byteRadix))
      decoded.append(UInt8(value % Self.byteRadix))
      index += Self.pairCharacterCount
    }
    if index < characters.count {
      guard
        index + Self.invalidRemainder < characters.count,
        let low = lookup[characters[index]],
        let high = lookup[characters[index + Self.invalidRemainder]]
      else {
        return nil
      }
      let value = low + high * Self.radix
      guard value < Self.byteRadix else { return nil }
      decoded.append(UInt8(value))
    }
    return Data(decoded)
  }
}
