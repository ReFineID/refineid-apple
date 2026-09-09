// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The vendored post-handshake frames.
internal struct TransportCorpus: Decodable {
  private enum CodingKeys: String, CodingKey {
    case format = "format"
    case maxFramePlaintext = "max_frame_plaintext"
    case maxFrameSize = "max_frame_size"
    case suites = "suites"
  }

  internal let format: String
  internal let maxFrameSize: Int
  internal let maxFramePlaintext: Int
  internal let suites: [TransportSuite]
}
