// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Liveness, attribution, framing, and policy against the tables

import Foundation
import Testing

@testable import RappEngine

private func check(_ passed: Bool, _ label: String) {
  #expect(passed, "\(label)")
}

// MARK: - Fixtures

/// Two channels wired to each other, as a completed handshake would leave them.
private func makeChannelPair() -> (RappSecureChannel, RappSecureChannel) {
  let firstKey = Data(repeating: RuntimeFixture.firstKeyFill, count: NoiseSizes.hashLength)
  let secondKey = Data(repeating: RuntimeFixture.secondKeyFill, count: NoiseSizes.hashLength)
  var initiatorSend = NoiseCipherState()
  var initiatorReceive = NoiseCipherState()
  var responderSend = NoiseCipherState()
  var responderReceive = NoiseCipherState()
  initiatorSend.initializeKey(firstKey)
  responderReceive.initializeKey(firstKey)
  responderSend.initializeKey(secondKey)
  initiatorReceive.initializeKey(secondKey)
  return (
    RappSecureChannel(send: initiatorSend, receive: initiatorReceive),
    RappSecureChannel(send: responderSend, receive: responderReceive)
  )
}

private let testSessionIdentifier = Data(
  repeating: RuntimeFixture.sessionFill, count: WireLimits.sessionIdentifier)

private func challenge(_ byte: UInt8) -> PingChallenge {
  guard let value = PingChallenge(Data(repeating: byte, count: PingChallenge.byteCount)) else {
    fatalError("fixed challenge fixture is the registered size")
  }
  return value
}

private let testPolicy = LivenessConfiguration(
  baseIntervalMilliseconds: RuntimeFixture.baseInterval,
  responseTimeoutMilliseconds: RuntimeFixture.responseTimeout,
  maximumIntervalMilliseconds: RuntimeFixture.maximumInterval,
  maximumJitterMilliseconds: 100,
  maximumMisses: RuntimeFixture.maximumMisses)

/// A connected pairing with a healthy session, as pairing leaves it.
private func establishedState(role: EndpointRole) -> RappState {
  var state = RappState(role: role)
  state.pairing = .pairedConnected
  state.session = .healthy
  return state
}

private func makeRuntime(
  role: EndpointRole,
  channel: RappSecureChannel,
  policy: LivenessConfiguration = testPolicy,
  startMilliseconds: UInt64 = 0
) -> EndpointRuntime {
  guard
    let tracker = try? LivenessTracker(
      configuration: policy, nowMilliseconds: startMilliseconds)
  else { fatalError("test policy is valid") }
  return EndpointRuntime(
    sessionIdentifier: testSessionIdentifier,
    channel: channel,
    state: establishedState(role: role),
    liveness: tracker)
}

// The scenario runs as one continuous drive, because that is what it proves:
// each step depends on the state the previous one left, and a peer answers a
// real predecessor rather than a fixture. Splitting it into separate tests
// would thread that state through setup and stop testing the sequence.
@Suite("RAPP endpoint runtime")
internal struct RuntimeDriveTests {
  @Test("Liveness, attribution, framing, and policy against the tables")
  internal func run() throws {
    // MARK: - 1. Liveness

    do {
      var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
      let sent = tracker.poll(
        nowMilliseconds: testPolicy.baseIntervalMilliseconds,
        nextChallenge: challenge(0x01),
        jitterMilliseconds: 0)
      check(sent == .sendPing(challenge(0x01)), "a due probe sends a ping")

      let wrong = tracker.receivePong(nowMilliseconds: 0, challenge: challenge(0x99))
      check(wrong == .ignoredUnmatched, "a wrong echo is discarded")
      check(tracker.hasOutstandingChallenge, "the challenge stays outstanding after a wrong echo")

      let exact = tracker.receivePong(nowMilliseconds: 0, challenge: challenge(0x01))
      check(exact == .accepted, "the exact echo proves liveness")
      check(!tracker.hasOutstandingChallenge, "an accepted echo clears the challenge")

      let stale = tracker.receivePong(nowMilliseconds: 0, challenge: challenge(0x01))
      check(stale == .ignoredUnmatched, "the same echo does not prove liveness twice")
    }

    do {
      var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
      var now = testPolicy.baseIntervalMilliseconds
      _ = tracker.poll(nowMilliseconds: now, nextChallenge: challenge(0x02), jitterMilliseconds: 0)
      now += testPolicy.responseTimeoutMilliseconds
      let missed = tracker.poll(
        nowMilliseconds: now, nextChallenge: challenge(0x03), jitterMilliseconds: 0)
      guard case .probeMissed = missed else {
        check(false, "an unanswered probe reports a miss")
        return
      }
      check(true, "an unanswered probe reports a miss")

      var closed = false
      for _ in 0..<Int(testPolicy.maximumMisses) {
        now += testPolicy.maximumIntervalMilliseconds
        _ = tracker.poll(
          nowMilliseconds: now, nextChallenge: challenge(0x04), jitterMilliseconds: 0)
        now += testPolicy.responseTimeoutMilliseconds
        if tracker.poll(
          nowMilliseconds: now, nextChallenge: challenge(0x05), jitterMilliseconds: 0)
          == .closeSession
        {
          closed = true
          break
        }
      }
      check(closed, "consecutive misses reach the hard deadline and close the session")
      check(
        tracker.poll(nowMilliseconds: now, nextChallenge: challenge(0x06), jitterMilliseconds: 0)
          == .alreadyClosed,
        "a closed tracker stays closed")
    }

    do {
      var runtime = makeRuntime(role: .requester, channel: makeChannelPair().0)
      var now = testPolicy.baseIntervalMilliseconds
      _ = runtime.poll(
        nowMilliseconds: now, nextChallenge: challenge(0x07), jitterMilliseconds: 0)
      check(
        runtime.currentState.operationAdmissionPermitted,
        "an outstanding probe alone does not block admission")
      now += testPolicy.responseTimeoutMilliseconds
      let missed = runtime.poll(
        nowMilliseconds: now, nextChallenge: challenge(0x08), jitterMilliseconds: 0)
      guard case .checking = missed else {
        check(false, "a missed probe moves the session to checking")
        return
      }
      check(true, "a missed probe moves the session to checking")
      check(
        !runtime.currentState.operationAdmissionPermitted,
        "checking blocks new operations")
      check(runtime.currentState.session == .checking, "the session state is checking")
    }

    // MARK: - 2. Injected backoff

    do {
      let slow = LivenessConfiguration(
        baseIntervalMilliseconds: 4_000,
        responseTimeoutMilliseconds: RuntimeFixture.responseTimeout,
        maximumIntervalMilliseconds: 64_000,
        maximumJitterMilliseconds: 0,
        maximumMisses: 4)

      func firstRetry(_ policy: LivenessConfiguration) throws -> UInt64 {
        var tracker = try LivenessTracker(configuration: policy, nowMilliseconds: 0)
        var now = policy.baseIntervalMilliseconds
        _ = tracker.poll(
          nowMilliseconds: now, nextChallenge: challenge(0x11), jitterMilliseconds: 0)
        now += policy.responseTimeoutMilliseconds
        guard
          case .probeMissed(let next) = tracker.poll(
            nowMilliseconds: now, nextChallenge: challenge(0x12), jitterMilliseconds: 0)
        else { return 0 }
        return next - now
      }

      let fastRetry = try firstRetry(testPolicy)
      let slowRetry = try firstRetry(slow)
      check(
        fastRetry != slowRetry,
        "two policies produce different schedules from the same events")
      check(
        fastRetry == testPolicy.baseIntervalMilliseconds * 2
          && slowRetry == slow.baseIntervalMilliseconds * 2,
        "the first retry is one exponential step from each policy's base")
    }

    do {
      var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
      var now = testPolicy.baseIntervalMilliseconds
      _ = tracker.poll(nowMilliseconds: now, nextChallenge: challenge(0x13), jitterMilliseconds: 0)
      now += testPolicy.responseTimeoutMilliseconds
      guard
        case .probeMissed(let withJitter) = tracker.poll(
          nowMilliseconds: now,
          nextChallenge: challenge(0x14),
          jitterMilliseconds: Int64(testPolicy.maximumJitterMilliseconds) * 4)
      else {
        check(false, "jitter is bounded by the policy")
        return
      }
      check(
        withJitter - now == testPolicy.baseIntervalMilliseconds * 2
          + testPolicy.maximumJitterMilliseconds,
        "jitter is clamped to the policy maximum")
      check(
        (try? LivenessConfiguration(
          baseIntervalMilliseconds: 0, responseTimeoutMilliseconds: 1,
          maximumIntervalMilliseconds: 1, maximumJitterMilliseconds: 0, maximumMisses: 1
        ).validated()) == nil,
        "a policy without a base interval is refused")
    }

    // MARK: - 3. Attribution

    do {
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)

      guard
        let ping = try? sender.send(
          messageType: .livenessPing,
          body: [
            "challenge": .bytes(challenge(0x21).bytes),
            "last_received_sequence": .unsigned(0),
          ])
      else {
        check(false, "a ping frame is produced")
        return
      }

      var tampered = ping.bytes
      tampered[tampered.startIndex] ^= 0xFF
      guard let tamperedFrame = try? BinaryFrame(reconstructing: tampered) else {
        check(false, "a tampered frame is still within the wire limit")
        return
      }
      let pairingBefore = receiver.currentState.pairing
      let outcome = receiver.receive(tamperedFrame, nowMilliseconds: 0)
      guard case .sessionClosed = outcome else {
        check(false, "a tampered frame closes the session")
        return
      }
      check(true, "a tampered frame closes the session")
      check(
        receiver.currentState.pairing == pairingBefore,
        "INV-18: an unattributable frame leaves the pairing untouched")
      check(!receiver.isOpen, "the session is closed after an integrity failure")
    }

    do {
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)

      // A message from an earlier phase decrypts, so it is attributable.
      guard
        let illegal = try? sender.send(
          messageType: .pairingHello,
          body: [
            "parameters": .map([:]), "display_name": .text("peer"), "platform": .text("test"),
          ])
      else {
        check(false, "an out-of-phase frame is produced")
        return
      }
      let outcome = receiver.receive(illegal, nowMilliseconds: 0)
      guard case .pairingEnded = outcome else {
        check(false, "a decrypted out-of-phase message ends the pairing")
        return
      }
      check(true, "a decrypted out-of-phase message ends the pairing")
      check(
        receiver.currentState.pairing != .pairedConnected,
        "the pairing left the connected state")
    }

    do {
      // The transport counter is implicit and lock-step, so a dropped frame
      // fails decryption before any sequence is read. An attributable gap is
      // therefore a frame that decrypts and then declares the wrong sequence.
      let (initiator, responder) = makeChannelPair()
      var rawSender = initiator
      var receiver = makeRuntime(role: .proxy, channel: responder)

      let ahead = Envelope(
        messageType: .livenessPing,
        sessionIdentifier: testSessionIdentifier,
        sequence: 7,
        body: [
          "challenge": .bytes(challenge(0x23).bytes),
          "last_received_sequence": .unsigned(0),
        ],
        critical: [],
        extensions: [:])
      let sealed = try rawSender.seal(try ahead.encoded())
      let frame = try BinaryFrame(reconstructing: sealed)
      guard case .pairingEnded = receiver.receive(frame, nowMilliseconds: 0) else {
        check(false, "a decrypted frame declaring a wrong sequence ends the pairing")
        return
      }
      check(true, "a decrypted frame declaring a wrong sequence ends the pairing")
    }

    do {
      // A dropped frame desynchronises the transport counter instead, which is
      // unattributable and must leave the pairing intact.
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)
      _ = try? sender.send(
        messageType: .livenessPing,
        body: [
          "challenge": .bytes(challenge(0x24).bytes), "last_received_sequence": .unsigned(0),
        ])
      guard
        let second = try? sender.send(
          messageType: .livenessPing,
          body: [
            "challenge": .bytes(challenge(0x25).bytes), "last_received_sequence": .unsigned(0),
          ])
      else {
        check(false, "a second ping frame is produced")
        return
      }
      let pairingBefore = receiver.currentState.pairing
      guard case .sessionClosed = receiver.receive(second, nowMilliseconds: 0) else {
        check(false, "a dropped frame is unattributable and closes only the session")
        return
      }
      check(true, "a dropped frame is unattributable and closes only the session")
      check(
        receiver.currentState.pairing == pairingBefore,
        "a dropped frame leaves the pairing intact")
    }

    // MARK: - 4. Framing

    do {
      let oversized = Data(repeating: 0, count: RappFrameLimits.maximumFrame + 1)
      var refused = false
      do {
        _ = try BinaryFrame(reconstructing: oversized)
      } catch RappFrameError.oversized(let got, let maximum) {
        refused = got == oversized.count && maximum == RappFrameLimits.maximumFrame
      } catch {
        refused = false
      }
      check(refused, "a frame above the wire limit is refused before any key is used")

      let exact = Data(repeating: 0, count: RappFrameLimits.maximumFrame)
      check(
        (try? BinaryFrame(reconstructing: exact)) != nil,
        "a frame exactly at the limit is admitted")

      guard let frame = try? BinaryFrame(reconstructing: Data([0x01, 0x02, 0x03])) else {
        check(false, "a small frame is admitted")
        return
      }
      let encoded = FrameFraming.encode(frame)
      check(
        encoded.count == FrameFraming.lengthPrefixBytes + frame.count,
        "the framing prefixes exactly the declared length")
      guard let decoded = try FrameFraming.decode(encoded) else {
        check(false, "a complete framed message decodes")
        return
      }
      check(decoded.frame == frame, "the framing round-trips")
      check(decoded.rest.isEmpty, "nothing follows a single framed message")
      let shortPrefix = try FrameFraming.decode(Data(encoded.prefix(1)))
      check(
        shortPrefix == nil,
        "a partial prefix is an ordinary short read, not a failure")
      let shortBody = try FrameFraming.decode(Data(encoded.dropLast()))
      check(
        shortBody == nil,
        "a partial body is an ordinary short read, not a failure")
      check(
        FrameFraming.lengthPrefixBytes == 2
          && RappFrameLimits.maximumFrame == Int(UInt16.max),
        "the prefix cannot express an oversized frame")
    }

    // MARK: - 5. The runtime does not restate the tables

    do {
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)

      // Drive the probe through poll so the tracker holds the challenge; a
      // hand-built ping would leave nothing outstanding to answer.
      guard
        case .send(let ping) = sender.poll(
          nowMilliseconds: testPolicy.baseIntervalMilliseconds,
          nextChallenge: challenge(0x31),
          jitterMilliseconds: 0)
      else {
        check(false, "a due probe produces a ping frame")
        return
      }
      let outcome = receiver.receive(ping, nowMilliseconds: 0)
      guard case .send(let pong) = outcome else {
        check(false, "a ping is answered centrally with a pong")
        return
      }
      check(true, "a ping is answered centrally with a pong")
      let accepted = sender.receive(pong, nowMilliseconds: 0)
      guard case .livenessRestored(let actions) = accepted else {
        check(false, "the exact echo restores liveness")
        return
      }
      var expected = establishedState(role: .requester)
      let reference = expected.livenessRestored()
      check(actions == reference, "the restore actions are exactly the tables' actions")
    }

    do {
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)

      var tampered = Data()
      if let frame = try? sender.send(
        messageType: .livenessPing,
        body: [
          "challenge": .bytes(challenge(0x32).bytes), "last_received_sequence": .unsigned(0),
        ])
      {
        tampered = frame.bytes
        tampered[tampered.index(before: tampered.endIndex)] ^= 0x01
      }
      guard let frame = try? BinaryFrame(reconstructing: tampered) else {
        check(false, "a tampered frame is built")
        return
      }
      guard case .sessionClosed(let actions) = receiver.receive(frame, nowMilliseconds: 0) else {
        check(false, "an integrity failure closes the session")
        return
      }
      var expected = establishedState(role: .proxy)
      let reference = expected.sessionIntegrityFailed()
      check(actions == reference, "the close actions are exactly the tables' actions")
    }

    do {
      // A pong nobody asked for is a stale-reference race, not a violation.
      let (initiator, responder) = makeChannelPair()
      var sender = makeRuntime(role: .requester, channel: initiator)
      var receiver = makeRuntime(role: .proxy, channel: responder)
      guard
        let pong = try? sender.send(
          messageType: .livenessPong,
          body: [
            "challenge": .bytes(challenge(0x33).bytes), "last_received_sequence": .unsigned(0),
          ])
      else {
        check(false, "an unsolicited pong is produced")
        return
      }
      let pairingBefore = receiver.currentState.pairing
      check(
        receiver.receive(pong, nowMilliseconds: 0) == .discarded(.staleReferenceRace),
        "a pong matching no ping is a stale-reference race")
      check(
        receiver.currentState.pairing == pairingBefore && receiver.isOpen,
        "a stale-reference race changes nothing")
    }

    do {
      check(
        UnexpectedInputClass.allCases.filter(\.mayEndPairing)
          == [.authenticatedProtocolViolation],
        "only the authenticated class may end a pairing")
      check(
        SecurityIncident.sessionIntegrityFailure.disposition.pairing == .keep
          && SecurityIncident.authenticatedProtocolViolation.disposition.pairing == .endImmediately,
        "the failure policy keeps the pairing for unattributable input")
      check(
        SecurityIncident.credentialRejected(.pin1).disposition.requiresNewUserIntent,
        "a refused credential requires fresh user intent")
    }

    // MARK: - Negative control

    do {
      var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
      _ = tracker.poll(
        nowMilliseconds: testPolicy.baseIntervalMilliseconds,
        nextChallenge: challenge(0x41),
        jitterMilliseconds: 0)
      // Accepting a mismatched echo would be the break; prove the harness sees it.
      let mismatched = tracker.receivePong(nowMilliseconds: 0, challenge: challenge(0x42))
      let brokenWouldPass = mismatched == .accepted
      check(!brokenWouldPass, "the harness rejects a mismatched echo being treated as proof")
    }
  }
}
