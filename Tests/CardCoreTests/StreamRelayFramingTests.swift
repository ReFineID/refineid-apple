// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import XCTest

/// Proves the stream endpoint literal grammar, the length-prefixed frame
/// bounds, and the send-side guards that need no live connection.
internal final class StreamRelayFramingTests: XCTestCase {
  private static let preamble = Data("test-stream-preamble".utf8)
  private static let applicationFrame = Data("test-application-frame".utf8)

  internal func testEndpointLiteralParsing() {
    let hostAndPort = StreamRelayEndpoint(literal: "192.0.2.7:4711")
    XCTAssertEqual(hostAndPort?.host, "192.0.2.7")
    XCTAssertEqual(hostAndPort?.port, 4_711)

    let named = StreamRelayEndpoint(literal: "requester.example:443")
    XCTAssertEqual(named?.host, "requester.example")
    XCTAssertEqual(named?.port, 443)

    let bracketedIPv6 = StreamRelayEndpoint(literal: "[2001:db8::17]:4711")
    XCTAssertEqual(bracketedIPv6?.host, "2001:db8::17")
    XCTAssertEqual(bracketedIPv6?.port, 4_711)

    XCTAssertNil(StreamRelayEndpoint(literal: "no-port"))
    XCTAssertNil(StreamRelayEndpoint(literal: ":4711"))
    XCTAssertNil(StreamRelayEndpoint(literal: "host:"))
    XCTAssertNil(StreamRelayEndpoint(literal: "host:0"))
    XCTAssertNil(StreamRelayEndpoint(literal: "host:65536"))
    XCTAssertNil(StreamRelayEndpoint(literal: "host:port"))
    XCTAssertNil(StreamRelayEndpoint(literal: "2001:db8::17:4711"))
  }

  internal func testFramingBounds() throws {
    let payload = Data("payload".utf8)
    let framed = try XCTUnwrap(StreamRelayFraming.encode(payload))
    XCTAssertEqual(framed.count, StreamRelayFraming.lengthPrefixByteCount + payload.count)
    XCTAssertEqual(
      StreamRelayFraming.payloadByteCount(
        lengthPrefix: framed.prefix(StreamRelayFraming.lengthPrefixByteCount)
      ),
      payload.count
    )

    let largest = Data(count: StreamRelayFraming.maximumPayloadByteCount)
    XCTAssertNotNil(StreamRelayFraming.encode(largest))
    let oversized = Data(count: StreamRelayFraming.maximumPayloadByteCount + 1)
    XCTAssertNil(StreamRelayFraming.encode(oversized))
    XCTAssertNil(StreamRelayFraming.encode(Data()))

    let zeroLengthPrefix = Data(count: StreamRelayFraming.lengthPrefixByteCount)
    XCTAssertNil(StreamRelayFraming.payloadByteCount(lengthPrefix: zeroLengthPrefix))
    XCTAssertNil(StreamRelayFraming.payloadByteCount(lengthPrefix: Data()))
  }

  internal func testSendWithoutConnectionThrows() async {
    let events = RecordedLog<StreamRelayEvent>()
    let session = StreamRelaySession(
      endpointLiterals: [],
      preamble: Self.preamble
    ) { event in
      events.append(event)
    }
    do {
      try await session.send(Self.applicationFrame)
      XCTFail("Send without a connection must throw")
    } catch let error as StreamRelayTransportError {
      XCTAssertEqual(error, .notConnected)
    } catch {
      XCTFail("Unexpected error type")
    }
  }

  internal func testSendRejectsInvalidFrameLengths() async {
    let events = RecordedLog<StreamRelayEvent>()
    let session = StreamRelaySession(
      endpointLiterals: [],
      preamble: Self.preamble
    ) { event in
      events.append(event)
    }
    let oversized = Data(count: StreamRelayFraming.maximumPayloadByteCount + 1)
    for frame in [Data(), oversized] {
      do {
        try await session.send(frame)
        XCTFail("Invalid frame length must throw")
      } catch let error as StreamRelayTransportError {
        XCTAssertEqual(error, .invalidFrameLength)
      } catch {
        XCTFail("Unexpected error type")
      }
    }
  }
}
