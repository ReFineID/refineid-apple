// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One sealed frame, with the counter it was sealed under.
internal struct TransportFrame: Decodable {
  private enum CodingKeys: String, CodingKey {
    case ciphertextHex = "ciphertext_hex"
    case counter = "counter"
    case direction = "direction"
    case plaintextHex = "plaintext_hex"
  }

  /// The direction whose frames the pairing initiator seals.
  internal static let initiatorToResponder = "initiator_to_responder"

  internal let direction: String
  internal let counter: UInt64
  internal let plaintextHex: String
  internal let ciphertextHex: String
}
