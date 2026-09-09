// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Bounds the registry fixes for the free-text and name fields a flow carries.
internal enum FlowLimit {
  /// Longest peer-chosen label, in bytes.
  internal static let labelBytes = 4_096

  /// Longest transport profile or candidate name, in bytes.
  internal static let transportNameBytes = 255

  /// Length of the nonce a session-ready proof carries.
  internal static let readyNonce = 32

  /// Length of a liveness challenge.
  internal static let livenessChallenge = 32
}
