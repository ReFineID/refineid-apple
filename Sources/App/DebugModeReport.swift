// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  /// What one debug mode produced: the lines to print, and whether the
  /// mode achieved what it was asked for.
  ///
  /// The success flag is the contract a driving script reads, because a
  /// shell loop has to tell a failed measurement from a finished one
  /// without parsing the text above it. Every mode answers with one of
  /// these, so there is one exit rule rather than one per probe -- the
  /// three card probes used to exit zero whatever they had just printed,
  /// which made `--sign-probe && next-step` run the next step after a card
  /// that had refused.
  ///
  /// DEBUG only.
  internal struct DebugModeReport {
    /// What the card probes put in a line that reports a failure.
    ///
    /// Their text is the measurement, and it is written for a person
    /// reading a console; this is the one token in it that is also read by
    /// a machine, so it is named here rather than spelled at each site.
    private static let failureMarker: String = "FAIL"

    /// The lines to print, in order.
    internal let lines: [String]

    /// Whether the mode achieved what it was asked for.
    internal let succeeded: Bool

    /// A report that states its own outcome.
    internal init(lines: [String], succeeded: Bool) {
      self.lines = lines
      self.succeeded = succeeded
    }

    /// A report judged by its own text: failed if any line reports a
    /// failure.
    ///
    /// For the card probes, which narrate a sequence of steps and mark the
    /// ones that did not work rather than stopping at the first.
    internal init(lines: [String]) {
      self.init(
        lines: lines,
        succeeded: !lines.contains { $0.contains(Self.failureMarker) })
    }
  }

#endif
