// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A parsed response APDU: bounded payload plus classified status word.
public struct ResponseApdu: Equatable, Sendable {
  /// The two trailing status bytes every response must carry.
  public static let statusWordLength: Int = 2

  /// The largest short-form payload a response may carry.
  public static let maximumPayloadLength: Int = ExpectedResponseLength.maximum

  /// The response body without the status word; may be empty.
  public let payload: Data

  /// The classified status word.
  public let statusWord: StatusWord

  /// Joins continuation parts inside the module.
  internal init(payload: Data, statusWord: StatusWord) {
    self.payload = payload
    self.statusWord = statusWord
  }

  /// Parses raw transport bytes; refuses responses shorter than a
  /// status word or larger than the short-form bound.
  public init?(raw: Data) {
    let bytes = Array(raw)
    guard
      bytes.count >= Self.statusWordLength,
      bytes.count <= Self.maximumPayloadLength + Self.statusWordLength
    else {
      return nil
    }
    let payloadLength = bytes.count - Self.statusWordLength
    self.payload = Data(bytes.prefix(payloadLength))
    self.statusWord = StatusWord(
      sw1: bytes[payloadLength],
      sw2: bytes[payloadLength + 1]
    )
  }
}
