// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Which credential a card refused.
internal enum CredentialKind: String, CaseIterable, Sendable {
  case cardAccessNumber = "can"
  case pin1 = "pin1"
  case pin2 = "pin2"
}
