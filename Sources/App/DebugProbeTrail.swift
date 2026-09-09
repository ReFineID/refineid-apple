// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import Foundation

  /// Everything a probe saw, in the order it saw it.
  ///
  /// The events a transport reports arrive on its own queue, and a probe
  /// reads them from another. One at a time is not enough here: the order
  /// is the answer.
  internal actor DebugProbeTrail {
    private var entries: [String] = []

    /// What has been seen so far, as one line.
    internal var summary: String {
      entries.isEmpty ? "nothing" : entries.joined(separator: ", ")
    }

    /// Adds one observation.
    internal func record(_ entry: String) {
      entries.append(entry)
    }

    /// Whether anything seen so far mentions `text`.
    internal func contains(_ text: String) -> Bool {
      entries.contains { $0.contains(text) }
    }
  }

#endif
