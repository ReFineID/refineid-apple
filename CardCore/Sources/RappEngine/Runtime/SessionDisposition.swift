// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// What becomes of the current session.
internal enum SessionDisposition: Equatable, Sendable {
  case closeImmediately
  case keep
}
