// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A liveness policy that could not describe a schedule.
internal enum LivenessError: Error, Equatable {
  case invalidConfiguration
}
