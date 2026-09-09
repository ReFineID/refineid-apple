// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Bounds every RAPP wire value is proved against before it is trusted.
internal enum WireLimits {
  /// Upper bound on one envelope plaintext, matching the frame limit.
  internal static let framePlaintext = 65_519

  /// Deepest nesting a wire value may reach before it is refused.
  internal static let nestingDepth = 8

  /// Longest text string a wire value may carry.
  internal static let textSize = 4_096

  /// Length of the session identifier every envelope carries.
  internal static let sessionIdentifier = 16
}
