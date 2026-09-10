// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// A tampered frame closes the session but leaves the pairing untouched.
internal func tamperedFrameClosesSession() {
  var challenges = ChallengeSource()
  let (initiator, responder) = makeChannelPair()
  var sender = makeRuntime(role: .requester, channel: initiator)
  var receiver = makeRuntime(role: .proxy, channel: responder)

  guard
    let ping = try? sender.send(
      messageType: .livenessPing,
      body: [
        "challenge": .bytes(challenges.next().bytes),
        "last_received_sequence": .unsigned(0),
      ])
  else {
    check(false, "a ping frame is produced")
    return
  }

  var tampered = ping.bytes
  tampered[tampered.startIndex] ^= tamperByteMask
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

/// A decrypted out-of-phase message ends the pairing.
internal func outOfPhaseEndsPairing() {
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

/// A decrypted frame declaring a wrong sequence ends the pairing.
internal func wrongSequenceEndsPairing() throws {
  var challenges = ChallengeSource()
  // The transport counter is implicit and lock-step, so a dropped frame
  // fails decryption before any sequence is read. An attributable gap is
  // therefore a frame that decrypts and then declares the wrong sequence.
  let (initiator, responder) = makeChannelPair()
  var rawSender = initiator
  var receiver = makeRuntime(role: .proxy, channel: responder)

  let ahead = Envelope(
    messageType: .livenessPing,
    sessionIdentifier: testSessionIdentifier,
    sequence: wrongSequenceNumber,
    body: [
      "challenge": .bytes(challenges.next().bytes),
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

/// A dropped frame closes only the session.
internal func droppedFrameClosesSessionOnly() {
  var challenges = ChallengeSource()
  // A dropped frame desynchronises the transport counter instead, which is
  // unattributable and must leave the pairing intact.
  let (initiator, responder) = makeChannelPair()
  var sender = makeRuntime(role: .requester, channel: initiator)
  var receiver = makeRuntime(role: .proxy, channel: responder)
  _ = try? sender.send(
    messageType: .livenessPing,
    body: [
      "challenge": .bytes(challenges.next().bytes), "last_received_sequence": .unsigned(0),
    ])
  guard
    let second = try? sender.send(
      messageType: .livenessPing,
      body: [
        "challenge": .bytes(challenges.next().bytes), "last_received_sequence": .unsigned(0),
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

/// Frames above the wire limit are refused; framing round-trips.
internal func framingLimits() throws {
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

  guard let frame = try? BinaryFrame(reconstructing: Data("abc".utf8)) else {
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
    FrameFraming.lengthPrefixBytes == MemoryLayout<UInt16>.size
      && RappFrameLimits.maximumFrame == Int(UInt16.max),
    "the prefix cannot express an oversized frame")
}

/// The restore actions are exactly the tables' actions.
internal func restoreActionsMatchTables() {
  var challenges = ChallengeSource()
  let (initiator, responder) = makeChannelPair()
  var sender = makeRuntime(role: .requester, channel: initiator)
  var receiver = makeRuntime(role: .proxy, channel: responder)

  // Drive the probe through poll so the tracker holds the challenge; a
  // hand-built ping would leave nothing outstanding to answer.
  guard
    case .send(let ping) = sender.poll(
      nowMilliseconds: testPolicy.baseIntervalMilliseconds,
      nextChallenge: challenges.next(),
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

/// The close actions are exactly the tables' actions.
internal func integrityFailureCloseActions() {
  var challenges = ChallengeSource()
  let (initiator, responder) = makeChannelPair()
  var sender = makeRuntime(role: .requester, channel: initiator)
  var receiver = makeRuntime(role: .proxy, channel: responder)

  var tampered = Data()
  if let frame = try? sender.send(
    messageType: .livenessPing,
    body: [
      "challenge": .bytes(challenges.next().bytes), "last_received_sequence": .unsigned(0),
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

/// A pong matching no ping is a stale-reference race.
internal func staleReferenceRace() {
  var challenges = ChallengeSource()
  // A pong nobody asked for is a stale-reference race, not a violation.
  let (initiator, responder) = makeChannelPair()
  var sender = makeRuntime(role: .requester, channel: initiator)
  var receiver = makeRuntime(role: .proxy, channel: responder)
  guard
    let pong = try? sender.send(
      messageType: .livenessPong,
      body: [
        "challenge": .bytes(challenges.next().bytes), "last_received_sequence": .unsigned(0),
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

/// Only the authenticated class may end a pairing.
internal func failurePolicyTable() {
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
