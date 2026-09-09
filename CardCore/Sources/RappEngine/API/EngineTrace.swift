// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import Foundation

  /// A stamped line from the operation engine, for reading a run back in
  /// order beside the holder's own trace.
  ///
  /// The engine decides the stage every answer is judged against, and a
  /// refusal names only the phase, not the stage that produced it. Saying
  /// the stage here is the difference between knowing an answer was refused
  /// and knowing why.
  internal enum EngineTrace {
    // MARK: Static Properties

    private static let started = Date()

    // MARK: Static Functions

    /// Writes one line, stamped with the seconds since the process began.
    internal static func say(_ line: String) {
      let elapsed = Date().timeIntervalSince(started)
      print(String(format: "[rapp-engine %7.3f] %@", elapsed, line))
      fflush(stdout)
    }
  }

#endif
