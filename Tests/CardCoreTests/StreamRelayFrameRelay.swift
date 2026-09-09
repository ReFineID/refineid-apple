// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import CardCore

/// Hands the frames one side of a stream channel reports to whoever wants
/// them, dropping the dialer's announcing byte.
///
/// That byte is the arrival and never a message, so a ceremony above must
/// not be given it as one.
internal actor StreamRelayFrameRelay {
  private var receiver: (@Sendable (Data) async -> Void)?
  private var waiting: [Data] = []
  private var events: [String] = []
  private var isConnected = false

  /// What this side saw, for a caller reporting why a ceremony stalled.
  internal var summary: String {
    events.joined(separator: ", ")
  }

  /// Answers once the channel has carried its arrival.
  internal var connected: Bool {
    isConnected
  }

  /// Names who receives the frames.
  internal func install(_ receiver: @escaping @Sendable (Data) async -> Void) async {
    self.receiver = receiver
    let held = waiting
    waiting.removeAll()
    for frame in held { await receiver(frame) }
  }

  /// Takes one event and passes on the frames worth passing on.
  internal func deliver(_ event: StreamRelayEvent) async {
    if case .connected = event { isConnected = true }
    if case .frame(let payload) = event, payload == StreamRelayPreamble.hello {
      isConnected = true
    }
    guard case .frame(let payload) = event, payload != StreamRelayPreamble.hello else {
      events.append(String(describing: event))
      return
    }
    events.append("frame(\(payload.count))")
    guard let receiver else {
      waiting.append(payload)
      return
    }
    await receiver(payload)
  }
}
