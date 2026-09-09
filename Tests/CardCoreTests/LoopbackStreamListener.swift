// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Network

/// A localhost requester-listener double for the stream transport tests.
///
/// It accepts one TCP connection on a loopback port, reads length-prefixed
/// frames, and follows its script after the first (preamble) frame.
internal final class LoopbackStreamListener: @unchecked Sendable {
  /// What the listener does after reading the preamble frame.
  internal enum Script {
    case closeAfterFirstFrame
    case echoFramesAfterFirst
    case zeroLengthPrefixAfterFirstFrame
  }

  private let queue = DispatchQueue(label: "fi.refineid.tests.stream-listener")
  private let listener: NWListener
  private let script: Script
  private let onFrame: @Sendable (Data) -> Void
  private let lock = NSLock()
  private var acceptedConnection: NWConnection?
  private var frameCount = 0

  /// Builds a loopback listener that reports every read frame.
  internal init(
    script: Script,
    onFrame: @escaping @Sendable (Data) -> Void
  ) throws {
    self.script = script
    self.onFrame = onFrame
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
      host: .ipv4(.loopback),
      port: .any
    )
    self.listener = try NWListener(using: parameters)
  }

  /// Starts listening and returns the bound loopback port.
  internal func start() async throws -> UInt16 {
    listener.newConnectionHandler = { [weak self] connection in
      self?.accept(connection)
    }
    return try await withCheckedThrowingContinuation { continuation in
      listener.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        switch state {
        case .ready:
          listener.stateUpdateHandler = nil
          continuation.resume(returning: listener.port?.rawValue ?? 0)

        case .failed(let error):
          listener.stateUpdateHandler = nil
          continuation.resume(throwing: error)

        case .setup, .waiting, .cancelled:
          break

        @unknown default:
          break
        }
      }
      listener.start(queue: queue)
    }
  }

  /// Sends one length-prefixed frame to the accepted peer, if any.
  internal func sendFrameToPeer(_ frame: Data) {
    lock.lock()
    let connection = acceptedConnection
    lock.unlock()
    guard let connection,
      let framed = StreamRelayFraming.encode(frame)
    else { return }
    connection.send(content: framed, completion: .idempotent)
  }

  /// Stops listening and closes the accepted connection.
  internal func stop() {
    listener.cancel()
    lock.lock()
    let connection = acceptedConnection
    acceptedConnection = nil
    lock.unlock()
    connection?.cancel()
  }

  private func accept(_ connection: NWConnection) {
    lock.lock()
    let isFirst = acceptedConnection == nil
    if isFirst { acceptedConnection = connection }
    lock.unlock()
    guard isFirst else {
      connection.cancel()
      return
    }
    connection.start(queue: queue)
    readPrefix(on: connection)
  }

  private func readPrefix(on connection: NWConnection) {
    connection.receive(
      minimumIncompleteLength: StreamRelayFraming.lengthPrefixByteCount,
      maximumLength: StreamRelayFraming.lengthPrefixByteCount
    ) { [weak self] data, _, _, error in
      guard let self, error == nil,
        let data,
        data.count == StreamRelayFraming.lengthPrefixByteCount,
        let byteCount = StreamRelayFraming.payloadByteCount(lengthPrefix: data)
      else { return }
      readPayload(byteCount: byteCount, on: connection)
    }
  }

  private func readPayload(byteCount: Int, on connection: NWConnection) {
    connection.receive(
      minimumIncompleteLength: byteCount,
      maximumLength: byteCount
    ) { [weak self] data, _, _, error in
      guard let self, error == nil,
        let data, data.count == byteCount
      else { return }
      handleFrame(data, on: connection)
      readPrefix(on: connection)
    }
  }

  private func handleFrame(_ frame: Data, on connection: NWConnection) {
    lock.lock()
    frameCount += 1
    let isPreamble = frameCount == 1
    lock.unlock()
    onFrame(frame)
    switch script {
    case .closeAfterFirstFrame:
      if isPreamble { connection.cancel() }

    case .echoFramesAfterFirst:
      guard !isPreamble,
        let framed = StreamRelayFraming.encode(frame)
      else { return }
      connection.send(content: framed, completion: .idempotent)

    case .zeroLengthPrefixAfterFirstFrame:
      guard isPreamble else { return }
      connection.send(
        content: Data(count: StreamRelayFraming.lengthPrefixByteCount),
        completion: .idempotent
      )
    }
  }
}
