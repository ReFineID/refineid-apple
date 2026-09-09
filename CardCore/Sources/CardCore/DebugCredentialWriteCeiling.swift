// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import Foundation
  import os

  /// A process-wide, DEBUG-only ceiling for destructive credential commands.
  ///
  /// The deliberate factory-card diagnostic launches the ordinary app with
  /// `--activation-single-step`. The first credential-bearing command may be
  /// serialized; attempting to serialize another ends the process before a
  /// second payload exists for any transport to send. Read-only APDUs are not
  /// counted.
  ///
  /// This is a diagnostic fuse, not activation policy. Normal Debug launches
  /// and every non-Debug build bypass it completely.
  internal enum DebugCredentialWriteCeiling {
    private static let launchArgument = "--activation-single-step"
    private static let serializedWrites = OSAllocatedUnfairLock(initialState: 0)

    /// Consumes the sole permit when the diagnostic launch argument is active.
    internal static func consumePermitIfEnabled() {
      guard ProcessInfo.processInfo.arguments.contains(Self.launchArgument) else { return }
      let permitted = Self.serializedWrites.withLock { count in
        guard count == 0 else { return false }
        count = 1
        return true
      }
      precondition(
        permitted,
        "DEBUG activation diagnostic refused a second credential-bearing command"
      )
    }
  }

#endif
