// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Digest lengths the registered signature algorithms consume.
internal enum DigestLength {
  internal static let sha224 = 28
  internal static let sha256 = 32
  internal static let sha384 = 48
  internal static let sha512 = 64
}
