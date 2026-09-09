// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation
  import RappEngine

  /// Wall and monotonic clocks in the millisecond units RAPP uses.
  public struct RappPlatformClock: Sendable {
    private static let nanosecondsPerMillisecond: UInt64 = 1_000_000
    private static let secondsPerMillisecond = 1_000.0

    /// Creates a system-backed clock.
    public init() {
      // platform default
    }

    /// Milliseconds since the Unix epoch; moves with wall-clock changes.
    public func wallMilliseconds() -> UInt64 {
      UInt64(Date().timeIntervalSince1970 * Self.secondsPerMillisecond)
    }

    /// Milliseconds of monotonic uptime; never moves backwards.
    public func monotonicMilliseconds() -> UInt64 {
      DispatchTime.now().uptimeNanoseconds / Self.nanosecondsPerMillisecond
    }
  }
#endif
