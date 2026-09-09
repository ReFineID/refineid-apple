// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Rejection of a field that failed its registered validation.
internal enum MessageFieldError: Error, Equatable {
  case invalidField(String)
}
