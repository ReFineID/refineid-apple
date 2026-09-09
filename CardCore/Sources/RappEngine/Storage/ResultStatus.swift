// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the specification registers them,
// so the source reads line for line against the document.
// swiftlint:disable sorted_enum_cases

import Foundation

/// Stable result state of an operation.
internal enum ResultStatus: String, Equatable {
  case completed = "completed"
  case denied = "denied"
  case cancelled = "cancelled"
  case rejected = "rejected"
  case credentialRejected = "credential_rejected"
  case ambiguous = "ambiguous"
}

// swiftlint:enable sorted_enum_cases
