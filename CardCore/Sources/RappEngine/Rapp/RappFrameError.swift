// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A frame that crossed a named limit before any key was used.
internal enum RappFrameError: Error, Equatable {
  case oversized(got: Int, maximum: Int)
}
