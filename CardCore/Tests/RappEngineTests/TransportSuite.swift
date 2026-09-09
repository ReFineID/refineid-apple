// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One suite's frames and the handshake they follow.
internal struct TransportSuite: Decodable {
  private enum CodingKeys: String, CodingKey {
    case frames = "frames"
    case handshakeHashHex = "handshake_hash_hex"
    case name = "name"
    case prologueHex = "prologue_hex"
    case suite = "suite"
  }

  internal let name: String
  internal let suite: String
  internal let prologueHex: String
  internal let handshakeHashHex: String
  internal let frames: [TransportFrame]
}
