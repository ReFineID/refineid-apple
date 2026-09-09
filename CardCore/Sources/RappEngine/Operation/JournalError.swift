// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A refused journal transition.
internal enum JournalError: Error, Equatable {
  case alreadyTransmitted
  case invalidState(state: OperationState)
  case persistence
  case requestHashMismatch
}
