// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The authenticated violations that end a pairing on first occurrence.
internal enum SessionViolation: Equatable {
  case duplicateReady
  case malformedMessage
  case parameterMismatch
  case unexpectedMessage
  case wireViolation
}
