// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A rejected operation construction, hash, or parse.
internal enum CardOperationError: Error, Equatable {
  case hashFailure
  case invalidDisplayContext
  case invalidField(field: String)
  case invalidIdentifier
  case invalidLifetime
  case keyAlgorithmMismatch
  case profileActionMismatch
  case profileNotGranted
  case requestHashMismatch
  case unexpectedField
  case unknownAction
  case unknownProfile
  case wrongDigestLength
}
