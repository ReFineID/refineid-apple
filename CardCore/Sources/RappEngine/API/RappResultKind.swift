// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Which answer an operation result carries.
public enum RappResultKind: Sendable {
  case certificate
  case identity
  case inspection
  case signature
}
