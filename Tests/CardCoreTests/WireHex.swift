// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// Test helper: hex-digit strings to bytes, so wire vectors stay
/// readable and no raw hex literals appear in test source.
internal enum WireHex {
  private static let hexRadix: Int = 16

  private static let digitsPerByte: Int = 2

  internal static func data(_ hexDigits: String) -> Data {
    let characters = Array(hexDigits)
    precondition(
      characters.count.isMultiple(of: digitsPerByte),
      "hex vector must have even length"
    )
    var bytes: [UInt8] = []
    bytes.reserveCapacity(characters.count / digitsPerByte)
    var index = characters.startIndex
    while index < characters.endIndex {
      let pair = String(characters[index...index.advanced(by: 1)])
      guard let byte = UInt8(pair, radix: hexRadix) else {
        preconditionFailure("invalid hex vector: \(hexDigits)")
      }
      bytes.append(byte)
      index = index.advanced(by: digitsPerByte)
    }
    return Data(bytes)
  }

  internal static func statusWord(_ hexDigits: String) -> StatusWord {
    let bytes = Array(data(hexDigits))
    precondition(bytes.count == digitsPerByte, "status word is exactly two bytes")
    return StatusWord(sw1: bytes[0], sw2: bytes[1])
  }
}
