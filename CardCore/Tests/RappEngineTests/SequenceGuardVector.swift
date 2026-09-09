// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One sequence the guard must accept or refuse.
internal struct SequenceGuardVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case acceptedSequences = "accepted_sequences"
    case expected = "expected"
    case expectedNextReceive = "expected_next_receive"
    case guardSessionIDHex = "guard_session_id_hex"
    case incomingSequence = "incoming_sequence"
    case incomingSessionIDHex = "incoming_session_id_hex"
    case name = "name"
  }

  internal let name: String
  internal let guardSessionIDHex: String
  internal let acceptedSequences: [UInt64]
  internal let incomingSessionIDHex: String
  internal let incomingSequence: UInt64
  internal let expected: String
  internal let expectedNextReceive: UInt64
}
