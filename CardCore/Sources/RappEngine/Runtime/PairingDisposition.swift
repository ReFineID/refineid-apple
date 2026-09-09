// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// What becomes of the long-term pairing.
internal enum PairingDisposition: Equatable, Sendable {
  /// Destroy the pair keys; a fresh scanned ceremony is the only recovery.
  case endImmediately
  case keep
}
