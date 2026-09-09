// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One flow-message body captured from the reference engine.
internal struct FlowVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case name = "name"
    case type = "type"
    case bodyHex = "body_hex"
  }

  internal let name: String
  internal let type: String
  internal let bodyHex: String
}
