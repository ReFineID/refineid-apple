// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A local fault that prevented a frame from being produced.
internal enum RuntimeSendError: Error, Equatable {
  case encoding(WireError)
  case sessionClosed
}
