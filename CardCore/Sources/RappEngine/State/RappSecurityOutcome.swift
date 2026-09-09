// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The ordered effects a security event produces across component machines.
internal struct RappSecurityOutcome: Sendable, Equatable {
  internal let actions: [RappAction]
}
