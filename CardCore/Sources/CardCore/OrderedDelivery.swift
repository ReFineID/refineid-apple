// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import os

/// Delivers work items one after another in enqueue order, bounded.
///
/// The RAPP coordinators decrypt with a strictly incrementing counter
/// nonce, so two deliveries racing into an actor out of order fail
/// authentication and fail-stop a healthy session. One chained task per
/// delivery keeps arrival order all the way in; the bound keeps a peer
/// that sends faster than this side consumes from growing the chain
/// without limit.
public final class OrderedDelivery: @unchecked Sendable {
  private struct Chain {
    var tail: Task<Void, Never>?
    var depth = 0
    var generation = 0
  }

  /// Deliveries a relay may queue: far above any healthy exchange, far
  /// below what a flooding peer could make this side retain.
  public static let relayFrameCapacity = 32

  private let capacity: Int
  private let chain = OSAllocatedUnfairLock(initialState: Chain())

  /// Bounds how many deliveries may wait at once.
  public init(capacity: Int) {
    self.capacity = capacity
  }

  /// Runs `work` after every delivery enqueued before it.
  ///
  /// Answers false - and enqueues nothing - when `capacity` deliveries
  /// are already waiting, which is a peer outrunning this side.
  @discardableResult
  @preconcurrency
  public func deliver(_ work: @escaping @Sendable () async -> Void) -> Bool {
    chain.withLock { state in
      guard state.depth < capacity else { return false }
      state.depth += 1
      let generation = state.generation
      let previous = state.tail
      state.tail = Task {
        await previous?.value
        let live = self.chain.withLock { $0.generation == generation }
        if live { await work() }
        self.chain.withLock { $0.depth = max(0, $0.depth - 1) }
      }
      return true
    }
  }

  /// Ends the current chain between connections: deliveries still
  /// waiting are skipped rather than run against the next connection.
  public func reset() {
    chain.withLock { state in
      state.generation += 1
      state.tail = nil
      state.depth = 0
    }
  }
}
