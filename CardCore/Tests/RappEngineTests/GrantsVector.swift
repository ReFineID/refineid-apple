// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One grant set and its digest.
internal struct GrantsVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case canonicalCBORHex = "canonical_cbor_hex"
    case name = "name"
    case profiles = "profiles"
    case sha256Hex = "sha256_hex"
  }

  internal let name: String
  internal let profiles: [String]
  internal let canonicalCBORHex: String
  internal let sha256Hex: String
}
