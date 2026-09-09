// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import Foundation

  /// Returns this device to a known zero before a measurement.
  ///
  /// Every measurement starts from zero or it is not a measurement. A
  /// smart-card token registered by yesterday's build answers the query
  /// today's build was meant to answer; a prime record written before a
  /// contents-version bump serves a login that should have failed; and an
  /// old trace line reads as if this run had produced it. Each of those
  /// has cost a wrong conclusion, so the reset clears all three and then
  /// prints what is left.
  ///
  /// What it does NOT clear is the stored card access number and PIN1.
  /// Those are the holder's own setup rather than measured state, and
  /// dropping them would make every reset cost a re-entry -- which is
  /// exactly the friction that stops a reset from being run.
  ///
  /// DEBUG only.
  ///
  /// Provenance: `--ctk-reset` in the donor
  /// `platform/apple/RefineID/Shared/RefineIDApp.swift`.
  internal enum DebugCardStateReset {
    /// Line break the diagnostics snapshot's text form uses.
    private static let newline: String = "\n"

    /// Clears the measured state and reports what remains.
    internal static func perform() -> [String] {
      var lines = CardStateReset.perform().lines
      lines += Self.remainingLines()
      return lines
    }

    /// The state a following measurement will actually start from.
    ///
    /// Read through the same snapshot the diagnostics screen uses, so the
    /// zero this claims to have reached is the zero everything else would
    /// report. A reset that graded its own work with its own ruler would be
    /// worth nothing.
    private static func remainingLines() -> [String] {
      ["-- state now --"]
        + DiagnosticsSnapshot.collect().text.components(separatedBy: Self.newline)
    }
  }

#endif
