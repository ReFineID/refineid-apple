// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Why a vendored vector could not be read.
internal enum CorpusError: Error {
  case invalidHex
  case missingHandshake(name: String)
  case notAMap(String)
}
