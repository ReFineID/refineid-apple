// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import Foundation

  /// A value one queue writes and another reads.
  internal final class DebugProbeOutcomeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    /// The value, if one was written.
    internal var value: String? {
      lock.lock()
      defer { lock.unlock() }
      return stored
    }

    /// Writes the value.
    internal func set(_ text: String) {
      lock.lock()
      defer { lock.unlock() }
      stored = text
    }
  }

#endif
