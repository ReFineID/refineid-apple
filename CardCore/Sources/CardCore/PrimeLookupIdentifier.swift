// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// An internal lookup key for a contactless card before PACE identifies it.
///
/// A contactless ATR identifies a card family, not one physical card. This
/// value therefore exists only to find the metadata that lets the extension
/// establish PACE. It must never be published as a CryptoTokenKit instance ID.
public struct PrimeLookupIdentifier: Equatable, Hashable, Sendable {
  /// A descriptive namespace keeps diagnostics readable without pretending
  /// this digest is a physical-card identity.
  private static let prefix = "refineid-prime-atr-sha256-"

  /// Formats one digest byte as two lowercase hexadecimal digits.
  private static let byteHexFormat = "%02x"

  /// The keychain account used for this ATR lookup.
  public let value: String

  /// Derives a lookup key from the complete answer to reset.
  ///
  /// Empty data identifies no card family and is refused.
  public init?(answerToReset: Data) {
    guard !answerToReset.isEmpty else { return nil }
    let digest = SHA256.hash(data: answerToReset)
      .map { byte in String(format: Self.byteHexFormat, byte) }
      .joined()
    self.value = Self.prefix + digest
  }
}
