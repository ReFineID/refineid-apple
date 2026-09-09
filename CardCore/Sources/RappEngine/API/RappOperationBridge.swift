// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The operation protocol running over one established session.
///
/// Every call answers with the bounded step the caller performs next. The
/// bridge decides what must happen; the caller performs it, so nothing here
/// touches a card, a transport, or a screen.
public final class RappOperationBridge: @unchecked Sendable {
  /// Which side of the pairing this bridge serves.
  internal enum Side {
    case proxy(ProxyOperationEngine)
    case requester(RequesterOperationEngine)
  }

  internal let lock = NSLock()
  internal let vault: RappOperationVault
  internal let pairIdentifier: Data
  internal let maximumLifetimeMilliseconds: UInt64
  internal var liveness: LivenessTracker
  internal var session: EstablishedSession
  internal var side: Side
  internal var closed = false

  internal init(
    vault: RappOperationVault,
    pairIdentifier: Data,
    session: EstablishedSession,
    side: Side,
    maximumLifetimeMs: UInt64,
    liveness: RappLivenessConfiguration,
    nowMilliseconds: UInt64
  ) throws {
    self.vault = vault
    self.pairIdentifier = pairIdentifier
    self.session = session
    self.side = side
    self.maximumLifetimeMilliseconds = maximumLifetimeMs
    do {
      self.liveness = try LivenessTracker(
        configuration: LivenessConfiguration(
          baseIntervalMilliseconds: liveness.baseIntervalMs,
          responseTimeoutMilliseconds: liveness.responseTimeoutMs,
          maximumIntervalMilliseconds: liveness.maximumIntervalMs,
          maximumJitterMilliseconds: liveness.maximumJitterMs,
          maximumMisses: liveness.maximumMisses),
        nowMilliseconds: nowMilliseconds)
    } catch {
      throw RappBindingError.InvalidInput
    }
  }
}
