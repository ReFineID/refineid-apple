// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One wire version and whether it is admitted.
internal struct WireVersionVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case expected = "expected"
    case name = "name"
    case version = "version"
  }

  internal let name: String
  internal let version: [UInt64]
  internal let expected: String
}
