// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Why a stream loopback did not complete.
internal enum StreamRelayTestFailure: Error {
  case noFrame
}
