// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore

extension Token {
  /// Stored contactless identities remain valid when a reader card is inserted.
  internal func supersedeStoredContactlessIdentities() {
    // Stored contactless identities remain valid across reader insertions.
  }
}
