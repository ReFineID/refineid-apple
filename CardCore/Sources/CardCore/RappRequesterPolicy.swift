// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(MultipeerConnectivity) && canImport(RappEngine)
  import Foundation
  import RappEngine

  /// Timing policy for one requester-side RAPP operation: the lifetime the
  /// operation is granted, the bound on the synchronous wait, and the pacing
  /// of liveness probes on the established channel.
  public struct RappRequesterPolicy: Sendable, Equatable {
    private enum Timing {
      static let interactiveOperationLifetimeMilliseconds: UInt64 = 120_000
      static let synchronousWaitTimeoutSeconds: TimeInterval = 125
      static let baseIntervalMilliseconds: UInt64 = 5_000

      /// How long a probe waits for its answer.
      ///
      /// A card read is not a stall: PACE and an on-card signature take
      /// several seconds with the holder's card on the phone, and a probe
      /// sent during one is answered when that work yields. Three seconds
      /// declared a working peer dead in the middle of the signature it had
      /// been asked for.
      static let responseTimeoutMilliseconds: UInt64 = 10_000
      static let maximumIntervalMilliseconds: UInt64 = 60_000
      static let maximumJitterMilliseconds: UInt64 = 500
      static let maximumMisses: UInt8 = 3
    }

    /// Longest wait for a paired device to be found at all.
    ///
    /// Long enough for a phone that is there, short enough that a phone
    /// that is not does not hold the screen.
    public static let defaultDiscoveryTimeout: TimeInterval = 12

    /// Provisional interactive policy.
    ///
    /// It is injectable so measured transport behavior can revise policy
    /// without adding UI timing heuristics.
    public static let interactive = Self(
      maximumOperationLifetimeMilliseconds: Timing.interactiveOperationLifetimeMilliseconds,
      synchronousWaitTimeout: Timing.synchronousWaitTimeoutSeconds,
      liveness: .init(
        baseIntervalMilliseconds: Timing.baseIntervalMilliseconds,
        responseTimeoutMilliseconds: Timing.responseTimeoutMilliseconds,
        maximumIntervalMilliseconds: Timing.maximumIntervalMilliseconds,
        maximumJitterMilliseconds: Timing.maximumJitterMilliseconds,
        maximumMisses: Timing.maximumMisses
      )
    )

    // MARK: Properties

    /// Operation lifetime granted to the RAPP runtime and sent as the
    /// expiry when the operation begins.
    public let maximumOperationLifetimeMilliseconds: UInt64
    /// Longest time ``RappPersistentRequesterClient/perform(_:)`` blocks
    /// before failing as timed out.
    public let synchronousWaitTimeout: TimeInterval

    /// Longest wait for a paired device to be found at all.
    public let discoveryTimeout: TimeInterval
    /// Liveness probing configuration for the established channel.
    public let liveness: RappOperationDriver.Liveness

    /// Composes a policy from explicit timing values.
    public init(
      maximumOperationLifetimeMilliseconds: UInt64,
      synchronousWaitTimeout: TimeInterval,
      liveness: RappOperationDriver.Liveness,
      discoveryTimeout: TimeInterval = Self.defaultDiscoveryTimeout
    ) {
      self.maximumOperationLifetimeMilliseconds = maximumOperationLifetimeMilliseconds
      self.synchronousWaitTimeout = synchronousWaitTimeout
      self.discoveryTimeout = discoveryTimeout
      self.liveness = liveness
    }
  }
#endif
