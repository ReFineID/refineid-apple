// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The encrypted channel with envelope framing and sequence enforcement.
///
/// Sealing allocates the one legal outgoing sequence; opening refuses anything
/// that is not the exact next incoming one, so a replayed or reordered frame
/// cannot advance the window.
internal struct RappMessageChannel {
  private var channel: RappSecureChannel

  private var sequence: SequenceGuard

  private let sessionIdentifier: Data

  /// The highest peer sequence accepted so far, for close and liveness bodies.
  internal var lastReceivedSequence: UInt64? { sequence.lastReceivedSequence }

  internal init(channel: RappSecureChannel, sessionIdentifier: Data) {
    self.channel = channel
    self.sessionIdentifier = sessionIdentifier
    self.sequence = SequenceGuard(sessionIdentifier: sessionIdentifier)
  }

  /// Seals one opaque payload, with no envelope around it.
  ///
  /// The cipher beneath already advances a nonce per frame in each
  /// direction, so ordering and replay are settled there. A caller that
  /// carries its own correlation needs nothing else from this layer.
  internal mutating func sealPayload(_ payload: Data) throws -> Data {
    try channel.seal(payload)
  }

  /// Opens one opaque payload.
  internal mutating func openPayload(_ frame: Data) throws -> Data {
    try channel.open(frame)
  }

  internal mutating func seal(
    _ messageType: MessageType, body: [String: WireValue]
  ) throws -> Data {
    let envelope = Envelope(
      messageType: messageType,
      sessionIdentifier: sessionIdentifier,
      sequence: try sequence.nextOutgoing(),
      body: body,
      critical: [],
      extensions: [:])
    return try channel.seal(try envelope.encoded())
  }

  /// Decrypt one frame into a schema-checked, correctly sequenced envelope.
  ///
  /// The cipher's counter nonce already refuses a replayed, reordered or
  /// skipped frame, so a decrypted envelope naming another session or a
  /// sequence off its nonce position can only be a peer that seals
  /// nonconforming envelopes - an authenticated protocol violation.
  internal mutating func open(_ frame: Data) throws -> Envelope {
    var decoded: Envelope?
    var guardCopy = sequence
    _ = try channel.open(frame) { plaintext in
      let envelope = try Envelope.decode(plaintext)
      try guardCopy.acceptIncoming(
        sessionIdentifier: envelope.sessionIdentifier, sequence: envelope.sequence)
      decoded = envelope
    }
    guard let envelope = decoded else { throw RappOpenFailure.authenticatedProtocolViolation }
    sequence = guardCopy
    return envelope
  }
}
