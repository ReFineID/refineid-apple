// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A typed failure.
///
/// Credentials and raw APDUs are deliberately absent.
public enum PersistentRelayFailure: Codable, Equatable, Error, Sendable {
  case busy
  case cardUnavailable
  case communication
  case invalidCard
  case missingCardAccessNumber
  case missingPIN1
  case pin1Blocked
  case pin1Rejected(remaining: Int?)
  case pin1RetryFloor
  case unsupportedAlgorithm
  case wrongCardAccessNumber
}
