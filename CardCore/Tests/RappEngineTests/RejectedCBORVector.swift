// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One encoding the decoder must refuse.
internal struct RejectedCBORVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case encodedHex = "encoded_hex"
    case error = "error"
    case name = "name"
  }

  internal let name: String
  internal let encodedHex: String
  internal let error: String
}
