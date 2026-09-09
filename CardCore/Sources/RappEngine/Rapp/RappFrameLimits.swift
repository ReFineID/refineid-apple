// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Named limits on one encrypted RAPP frame.
internal enum RappFrameLimits {
  /// Largest frame accepted on the wire, tag included.
  internal static let maximumFrame = 65_535

  /// Largest plaintext that still fits a frame once the tag is added.
  internal static let maximumPlaintext = maximumFrame - NoiseSizes.tagLength
}
