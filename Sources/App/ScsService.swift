// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)
  import Foundation

  /// The one SCS instance the app runs, started at launch.
  internal enum ScsService {
    /// Created and started exactly once; `static let` gives the
    /// once-semantics.
    private static let server: ScsServer = {
      let created = ScsServer()
      created.start()
      return created
    }()

    /// Starts the localhost SCS if it is not already running.
    internal static func startIfNeeded() {
      _ = Self.server
    }
  }
#endif
