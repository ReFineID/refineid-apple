// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A refused authorization step.
internal enum AuthorizationError: Error, Equatable {
  case approvalMismatch
  case commitMismatch
  case expired
  case invalidResult
  case journal(JournalError)
  case wrongStage(stage: AuthorizationStage)
}
