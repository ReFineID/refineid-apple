// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The card status fixed when the completed-inspection body was captured.
internal struct OperationInspectionInput: Decodable {
  private enum CodingKeys: String, CodingKey {
    case pin1Factory = "pin1_factory"
    case pin2Factory = "pin2_factory"
    case pin1Attempts = "pin1_attempts"
    case pin2Attempts = "pin2_attempts"
    case pukAttempts = "puk_attempts"
  }

  internal let pin1Factory: Bool
  internal let pin2Factory: Bool
  internal let pin1Attempts: UInt8?
  internal let pin2Attempts: UInt8?
  internal let pukAttempts: UInt8?
}
