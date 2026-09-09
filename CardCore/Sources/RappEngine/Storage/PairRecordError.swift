// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Rejection of a stored pairing, matching the single coarse failure the
/// binding boundary reports.
internal enum PairRecordError: Error, Equatable {
  case invalidInput
}
