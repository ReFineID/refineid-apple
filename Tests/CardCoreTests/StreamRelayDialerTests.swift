// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Network
import XCTest

/// Proves that `StreamRelaySession` dialer lifecycle operations are idempotent
/// and do not generate redundant concurrent connection attempts.
internal final class StreamRelayDialerTests: XCTestCase {
  private static let eventTimeout: TimeInterval = 10
  private static let quietWindowMilliseconds = 300
  private static let repeatStartAttempts = 5
  private static let singleConnectionCount = 1
  private static let preamble = Data("test-stream-preamble".utf8)

  internal func testMultipleStartsAreIdempotentAndDoNotDuplicateConnections() async throws {
    let listenerFrames = RecordedLog<Data>()
    let events = RecordedLog<StreamRelayEvent>()
    let connected = expectation(description: "session reported connected")

    let listener = try LoopbackStreamListener(script: .echoFramesAfterFirst) { frame in
      listenerFrames.append(frame)
    }
    let port = try await listener.start()
    let session = StreamRelaySession(
      endpointLiterals: ["127.0.0.1:\(port)"],
      preamble: Self.preamble
    ) { event in
      events.append(event)
      if case .connected = event {
        connected.fulfill()
      }
    }

    for _ in 0..<Self.repeatStartAttempts {
      session.start()
    }
    await fulfillment(of: [connected], timeout: Self.eventTimeout)

    try await Task.sleep(for: .milliseconds(Self.quietWindowMilliseconds))
    let connectedCount = events.values.count { event in
      guard case .connected = event else { return false }
      return true
    }
    XCTAssertEqual(connectedCount, Self.singleConnectionCount)
    XCTAssertEqual(listenerFrames.values, [Self.preamble])

    session.cancel()
    listener.stop()
  }
}
