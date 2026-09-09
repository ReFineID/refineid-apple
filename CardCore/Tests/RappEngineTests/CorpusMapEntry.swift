// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One entry of a described corpus map.
internal struct CorpusMapEntry: Decodable {
  private enum CodingKeys: String, CodingKey {
    case key = "key"
    case value = "value"
  }

  internal let key: String
  internal let value: CorpusValue
}
