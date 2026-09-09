// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One golden deterministic encoding.
internal struct CBORVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case encodedHex = "encoded_hex"
    case name = "name"
    case value = "value"
  }

  internal let name: String
  internal let value: CorpusValue
  internal let encodedHex: String
}
