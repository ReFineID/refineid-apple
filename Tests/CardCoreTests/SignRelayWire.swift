// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import CardCore

#if canImport(RappEngine)

  /// Carries frames between two sessions in one process.
  internal actor SignRelayWire {
    private static let maximumWaits = 200

    /// How long each wait for the handshake to settle lasts.
    private static let waitIntervalMilliseconds = 10
    private static let waitInterval = Duration.milliseconds(waitIntervalMilliseconds)

    private let requester: SignRelaySession
    private let proxy: SignRelaySession
    private var answer: (@Sendable (PersistentRelayMessage) -> PersistentRelayMessage)?
    private var pending: CheckedContinuation<PersistentRelayMessage, Error>?

    /// Wires the two sides together.
    internal init(requester: SignRelaySession, proxy: SignRelaySession) {
      self.requester = requester
      self.proxy = proxy
    }

    /// Sets what the proxy answers with.
    internal func answerWith(
      _ answer: @escaping @Sendable (PersistentRelayMessage) -> PersistentRelayMessage
    ) {
      self.answer = answer
    }

    /// Drives both sides until each reports an established session.
    internal func establish() async throws {
      for frame in try await requester.start().send {
        await deliverToProxy(frame)
      }
      var waited = 0
      while waited < Self.maximumWaits {
        let requesterReady = await requester.isEstablished
        let proxyReady = await proxy.isEstablished
        if requesterReady, proxyReady { return }
        try await Task.sleep(for: Self.waitInterval)
        waited += 1
      }
    }

    /// Sends one request and waits for its answer.
    internal func ask(_ request: PersistentRelayMessage) async throws -> PersistentRelayMessage {
      let frame = try await requester.seal(try request.encoded())
      return try await withCheckedThrowingContinuation { continuation in
        pending = continuation
        Task { await deliverToProxy(frame) }
      }
    }

    private func deliverToProxy(_ frame: Data) async {
      guard let step = try? await proxy.receive(frame) else { return }
      for outgoing in step.send {
        await deliverToRequester(outgoing)
      }
      guard
        let payload = step.payload,
        let request = try? PersistentRelayMessage.decoded(payload),
        let reply = answer?(request),
        let sealed = try? await proxy.seal(try reply.encoded())
      else { return }
      await deliverToRequester(sealed)
    }

    private func deliverToRequester(_ frame: Data) async {
      guard let step = try? await requester.receive(frame) else { return }
      for outgoing in step.send {
        await deliverToProxy(outgoing)
      }
      guard
        let payload = step.payload,
        let message = try? PersistentRelayMessage.decoded(payload)
      else { return }
      pending?.resume(returning: message)
      pending = nil
    }
  }
#endif
