// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// A slow backoff policy the schedule compares against.
internal let slowBackoffBaseIntervalMilliseconds: UInt64 = 4_000
internal let slowBackoffMaximumIntervalMilliseconds: UInt64 = 64_000
internal let slowBackoffMaximumMisses: UInt8 = 4
/// The exponential step the first retry takes from each policy's base.
internal let retryStepFactor: UInt64 = 2
/// The jitter multiple the bound check stresses with.
internal let jitterStressMultiplier: Int64 = 4
/// A sequence no live session has declared.
internal let wrongSequenceNumber: UInt64 = 7

/// The first retry delay one policy schedules after one miss.
internal func firstRetry(
  _ policy: LivenessConfiguration, first: PingChallenge, second: PingChallenge
) throws -> UInt64 {
  var tracker = try LivenessTracker(configuration: policy, nowMilliseconds: 0)
  var now = policy.baseIntervalMilliseconds
  _ = tracker.poll(
    nowMilliseconds: now, nextChallenge: first, jitterMilliseconds: 0)
  now += policy.responseTimeoutMilliseconds
  guard
    case .probeMissed(let next) = tracker.poll(
      nowMilliseconds: now, nextChallenge: second, jitterMilliseconds: 0)
  else { return 0 }
  return next - now
}

/// An exact echo proves liveness; a wrong or repeated echo does not.
internal func livenessEchoProof() throws {
  var challenges = ChallengeSource()
  let ping = challenges.next()
  let wrongPing = challenges.next()
  var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
  let sent = tracker.poll(
    nowMilliseconds: testPolicy.baseIntervalMilliseconds,
    nextChallenge: ping,
    jitterMilliseconds: 0)
  check(sent == .sendPing(ping), "a due probe sends a ping")

  let wrong = tracker.receivePong(nowMilliseconds: 0, challenge: wrongPing)
  check(wrong == .ignoredUnmatched, "a wrong echo is discarded")
  check(tracker.hasOutstandingChallenge, "the challenge stays outstanding after a wrong echo")

  let exact = tracker.receivePong(nowMilliseconds: 0, challenge: ping)
  check(exact == .accepted, "the exact echo proves liveness")
  check(!tracker.hasOutstandingChallenge, "an accepted echo clears the challenge")

  let stale = tracker.receivePong(nowMilliseconds: 0, challenge: ping)
  check(stale == .ignoredUnmatched, "the same echo does not prove liveness twice")
}

/// Consecutive misses reach the hard deadline and close the session.
internal func missDeadlineClosesSession() throws {
  var challenges = ChallengeSource()
  var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
  var now = testPolicy.baseIntervalMilliseconds
  _ = tracker.poll(nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
  now += testPolicy.responseTimeoutMilliseconds
  let missed = tracker.poll(
    nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
  guard case .probeMissed = missed else {
    check(false, "an unanswered probe reports a miss")
    return
  }
  check(true, "an unanswered probe reports a miss")

  var closed = false
  for _ in 0..<Int(testPolicy.maximumMisses) {
    now += testPolicy.maximumIntervalMilliseconds
    _ = tracker.poll(
      nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
    now += testPolicy.responseTimeoutMilliseconds
    if tracker.poll(
      nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
      == .closeSession
    {
      closed = true
      break
    }
  }
  check(closed, "consecutive misses reach the hard deadline and close the session")
  check(
    tracker.poll(nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
      == .alreadyClosed,
    "a closed tracker stays closed")
}

/// A missed probe moves the session to checking, which blocks new operations.
internal func checkingBlocksAdmission() {
  var challenges = ChallengeSource()
  var runtime = makeRuntime(role: .requester, channel: makeChannelPair().0)
  var now = testPolicy.baseIntervalMilliseconds
  _ = runtime.poll(
    nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
  check(
    runtime.currentState.operationAdmissionPermitted,
    "an outstanding probe alone does not block admission")
  now += testPolicy.responseTimeoutMilliseconds
  let missed = runtime.poll(
    nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
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

/// Two policies produce different schedules from the same events.
internal func backoffSchedule() throws {
  var challenges = ChallengeSource()
  let slow = LivenessConfiguration(
    baseIntervalMilliseconds: slowBackoffBaseIntervalMilliseconds,
    responseTimeoutMilliseconds: RuntimeFixture.responseTimeout,
    maximumIntervalMilliseconds: slowBackoffMaximumIntervalMilliseconds,
    maximumJitterMilliseconds: 0,
    maximumMisses: slowBackoffMaximumMisses)

  let fastRetry = try firstRetry(testPolicy, first: challenges.next(), second: challenges.next())
  let slowRetry = try firstRetry(slow, first: challenges.next(), second: challenges.next())
  check(
    fastRetry != slowRetry,
    "two policies produce different schedules from the same events")
  check(
    fastRetry == testPolicy.baseIntervalMilliseconds * retryStepFactor
      && slowRetry == slow.baseIntervalMilliseconds * retryStepFactor,
    "the first retry is one exponential step from each policy's base")
}

/// Jitter is clamped to the policy maximum.
internal func jitterBounded() throws {
  var challenges = ChallengeSource()
  var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
  var now = testPolicy.baseIntervalMilliseconds
  _ = tracker.poll(nowMilliseconds: now, nextChallenge: challenges.next(), jitterMilliseconds: 0)
  now += testPolicy.responseTimeoutMilliseconds
  guard
    case .probeMissed(let withJitter) = tracker.poll(
      nowMilliseconds: now,
      nextChallenge: challenges.next(),
      jitterMilliseconds: Int64(testPolicy.maximumJitterMilliseconds) * jitterStressMultiplier)
  else {
    check(false, "jitter is bounded by the policy")
    return
  }
  check(
    withJitter - now == testPolicy.baseIntervalMilliseconds * retryStepFactor
      + testPolicy.maximumJitterMilliseconds,
    "jitter is clamped to the policy maximum")
  check(
    (try? LivenessConfiguration(
      baseIntervalMilliseconds: 0, responseTimeoutMilliseconds: 1,
      maximumIntervalMilliseconds: 1, maximumJitterMilliseconds: 0, maximumMisses: 1
    ).validated()) == nil,
    "a policy without a base interval is refused")
}

/// The harness rejects a mismatched echo being treated as proof.
internal func negativeControlMismatchedEcho() throws {
  var challenges = ChallengeSource()
  let ping = challenges.next()
  let strayPing = challenges.next()
  var tracker = try LivenessTracker(configuration: testPolicy, nowMilliseconds: 0)
  _ = tracker.poll(
    nowMilliseconds: testPolicy.baseIntervalMilliseconds,
    nextChallenge: ping,
    jitterMilliseconds: 0)
  // Accepting a mismatched echo would be the break; prove the harness sees it.
  let mismatched = tracker.receivePong(nowMilliseconds: 0, challenge: strayPing)
  let brokenWouldPass = mismatched == .accepted
  check(!brokenWouldPass, "the harness rejects a mismatched echo being treated as proof")
}
