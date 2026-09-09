// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One direction of an in-process transport.
///
/// The frame is handed over without waiting for the peer to finish with it,
/// which is the ordering a real transport gives: waiting inline would
/// suspend the sender inside its own actor while the peer tried to reply
/// into that same actor.
internal actor SignRelayFrameEndpoint {
  private var receiver: (@Sendable (Data) async -> Void)?

  /// Names who receives what this endpoint sends.
  internal func install(_ receiver: @escaping @Sendable (Data) async -> Void) {
    self.receiver = receiver
  }

  /// Hands one frame to the peer.
  internal func send(_ frame: Data) async {
    guard let receiver else { return }
    Task { await receiver(frame) }
    await Task.yield()
  }

  /// Ends this direction.
  internal func close() {
    receiver = nil
  }
}
