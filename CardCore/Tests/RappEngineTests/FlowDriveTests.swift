// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Both endpoints complete pairing and a session in one process

import CryptoKit
import Foundation
import Testing

@testable import RappEngine

private func check(_ passed: Bool, _ label: String) {
  #expect(passed, "\(label)")
}

// The scenario runs as one continuous drive, because that is what it proves:
// each step depends on the state the previous one left, and a peer answers a
// real predecessor rather than a fixture. Splitting it into separate tests
// would thread that state through setup and stop testing the sequence.
@Suite("RAPP pairing and session flows")
internal struct FlowDriveTests {
  @Test("Both endpoints complete pairing and a session in one process")
  internal func run() throws {
    // MARK: - 1. The pairing ceremony

    let everyProfile: [ProfileName] = [.cardStatus, .authentication, .documentSigning]
    let ceremonyOffer = try makeOffer(profiles: everyProfile)
    let peers = try runPairing(offer: ceremonyOffer, grants: everyProfile)

    check(
      peers.requesterPairIdentifier == peers.proxyPairIdentifier,
      "both sides derive one pair identifier")
    check(
      peers.requester.pairIdentifier == peers.proxy.pairIdentifier,
      "the record carries that identifier")
    check(
      peers.requester.rendezvousToken == peers.proxy.rendezvousToken,
      "both derive one rendezvous token")
    check(peers.requester.grantsHash == peers.proxy.grantsHash, "both derive one grants hash")
    check(peers.requester.profiles == peers.proxy.profiles, "both agree on the granted profiles")
    check(
      peers.requester.grantsHash
        == (try RappHashes.grantsHash(profiles: everyProfile.map(\.rawValue))),
      "the grants hash is the digest of the granted set")
    check(
      peers.requester.role == .requester && peers.proxy.role == .proxy,
      "each side stores its own role")
    check(
      peers.requester.localStaticPublic == peers.proxy.remoteStaticPublic
        && peers.proxy.localStaticPublic == peers.requester.remoteStaticPublic,
      "each side authenticated the other's static key")
    check(
      peers.requester.transport == peers.proxy.transport, "both bind the same transport candidate")

    // The stored order is fixed by the name bytes, so the record encodes the
    // same way on both peers and matches the reference engine.
    check(
      peers.requester.profiles == [.authentication, .cardStatus, .documentSigning],
      "granted profiles are stored ordered by their name bytes")

    // The two records differ only in role and key ownership, so re-encoding one
    // with the other's role-specific fields must reproduce it byte for byte.
    let mirrored = try PairRecord(
      pairIdentifier: peers.proxy.pairIdentifier,
      rendezvousToken: peers.proxy.rendezvousToken,
      role: .requester,
      localStaticPrivate: peers.requester.localStaticPrivate,
      localStaticPublic: peers.requester.localStaticPublic,
      remoteStaticPublic: peers.requester.remoteStaticPublic,
      grantsHash: peers.proxy.grantsHash,
      profiles: peers.proxy.profiles,
      transport: peers.proxy.transport,
      createdAtMilliseconds: peers.proxy.createdAtMilliseconds)
    check(
      (try mirrored.encoded()) == (try peers.requester.encoded()),
      "the records match byte for byte outside role and key ownership")

    // MARK: - 2. A session over the stored pairing

    var (requesterSession, proxySession) = try runSession(peers)
    check(
      requesterSession.sessionIdentifier == proxySession.sessionIdentifier,
      "both sides derive one session identifier")
    check(
      requesterSession.sessionIdentifier != peers.requester.pairIdentifier,
      "the session identifier is not the pair identifier")

    // The slim relay's channel: a payload with no envelope over it, which
    // brings its own correlation and needs the cipher and nothing else.
    let slim = Data("one request".utf8)
    check(
      try proxySession.openPayload(try requesterSession.sealPayload(slim)) == slim
        && (try requesterSession.openPayload(try proxySession.sealPayload(slim))) == slim,
      "an opaque payload crosses the session both ways unchanged")

    let challenge = randomBytes(FlowLimit.livenessChallenge)
    let pingFrame = try requesterSession.seal(
      .livenessPing, body: ["challenge": .bytes(challenge), "last_received_sequence": .unsigned(0)])
    let openedPing = try proxySession.open(pingFrame)
    check(openedPing.messageType == .livenessPing, "a sealed message opens on the other side")
    check(openedPing.body["challenge"] == .bytes(challenge), "the payload survives the channel")

    // MARK: - 3. Grants

    let intersection = grantIntersection(
      offered: everyProfile, requested: [.cardStatus, .authentication])
    check(
      intersection == sortedByNameBytes([.cardStatus, .authentication]),
      "the intersection is the common set")

    let subsetPeers = try runPairing(
      offer: try makeOffer(profiles: everyProfile), grants: intersection)
    check(subsetPeers.requester.profiles == intersection, "a granted subset is what gets stored")
    check(
      subsetPeers.requester.grantsHash != peers.requester.grantsHash,
      "a different grant set hashes differently")

    do {
      _ = try runPairing(offer: try makeOffer(profiles: everyProfile), grants: [])
      check(false, "an empty grant set is refused")
    } catch PairingError.invalidGrantSet {
      check(true, "an empty grant set is refused")
    } catch {
      check(false, "an empty grant set is refused")
    }

    do {
      _ = try runPairing(offer: try makeOffer(profiles: [.cardStatus]), grants: [.documentSigning])
      check(false, "a grant outside the offered set is refused")
    } catch PairingError.invalidGrantSet {
      check(true, "a grant outside the offered set is refused")
    } catch {
      check(false, "a grant outside the offered set is refused")
    }

    // MARK: - 4. Offer expiry

    let shortLifetime: UInt64 = 60_000
    let expiringOffer = try makeOffer(profiles: everyProfile, lifetimeMilliseconds: shortLifetime)
    let expiringDeadline = try PairingOfferDeadline(offer: expiringOffer, startedAtMilliseconds: 0)
    check(
      expiringDeadline.isLive(nowMilliseconds: shortLifetime - 1),
      "the offer is live just inside its lifetime")
    check(
      !expiringDeadline.isLive(nowMilliseconds: shortLifetime),
      "the offer is dead once the lifetime elapses")

    do {
      _ = try PairingHandshake.begin(
        role: .requester, offer: expiringOffer, candidateIdentifier: "stream-1",
        localKeys: PairKeyMaterial(), deadline: expiringDeadline, nowMilliseconds: shortLifetime)
      check(false, "a ceremony started after the deadline is refused")
    } catch let failure as PairingAttemptFailure {
      check(failure.error == .offerExpired, "a ceremony started after the deadline is refused")
    } catch {
      check(false, "a ceremony started after the deadline is refused")
    }

    _ = try runPairing(
      offer: expiringOffer, grants: everyProfile, nowMilliseconds: shortLifetime - 1)
    check(true, "a ceremony started just inside the deadline completes")

    // MARK: - 5. Liveness

    // The tracker owns the schedule, so a probe is registered by polling it.
    let policy = LivenessConfiguration(
      baseIntervalMilliseconds: 1_000, responseTimeoutMilliseconds: 500,
      maximumIntervalMilliseconds: 8_000, maximumJitterMilliseconds: 100, maximumMisses: 3)
    var tracker = try LivenessTracker(configuration: policy, nowMilliseconds: 0)
    let outstanding = try #require(PingChallenge(randomBytes(PingChallenge.byteCount)))
    let other = try #require(PingChallenge(randomBytes(PingChallenge.byteCount)))
    check(
      tracker.receivePong(nowMilliseconds: 0, challenge: outstanding) == .ignoredUnmatched,
      "a pong with no ping proves nothing")
    check(
      tracker.poll(nowMilliseconds: 1_000, nextChallenge: outstanding, jitterMilliseconds: 0)
        == .sendPing(outstanding), "a due probe sends the challenge")
    check(
      tracker.receivePong(nowMilliseconds: 1_010, challenge: other) == .ignoredUnmatched,
      "a mismatched echo is discarded")
    check(tracker.hasOutstandingChallenge, "the challenge stays outstanding after a mismatch")
    check(
      tracker.receivePong(nowMilliseconds: 1_020, challenge: outstanding) == .accepted,
      "the exact echo proves liveness")
    check(!tracker.hasOutstandingChallenge, "an accepted echo clears the challenge")
    check(
      tracker.receivePong(nowMilliseconds: 1_030, challenge: outstanding) == .ignoredUnmatched,
      "the same echo does not prove liveness twice")

    // MARK: - 6. Failure paths

    let twoCandidateOffer = try makeOffer(
      profiles: everyProfile, candidates: ["stream-1", "nearby-1"])
    let twoCandidateDeadline = try PairingOfferDeadline(
      offer: twoCandidateOffer, startedAtMilliseconds: 0)

    do {
      _ = try PairingHandshake.begin(
        role: .requester, offer: twoCandidateOffer, candidateIdentifier: "absent",
        localKeys: PairKeyMaterial(), deadline: twoCandidateDeadline, nowMilliseconds: 0)
      check(false, "an unknown candidate is refused")
    } catch let failure as PairingAttemptFailure {
      check(failure.error == .candidateNotUnique, "an unknown candidate is refused")
    } catch {
      check(false, "an unknown candidate is refused")
    }

    // A failed candidate hands the offer back, and the next candidate reuses it.
    let firstAttempt = try PairingHandshake.begin(
      role: .requester, offer: twoCandidateOffer, candidateIdentifier: "stream-1",
      localKeys: PairKeyMaterial(), deadline: twoCandidateDeadline, nowMilliseconds: 0)
    let recoveredOffer = firstAttempt.abort()
    let fallbackPeers = try runPairing(
      offer: recoveredOffer, grants: everyProfile, candidateIdentifier: "nearby-1")
    check(
      fallbackPeers.requester.transport.candidateIdentifier == "nearby-1",
      "an aborted candidate returns the offer and the next candidate pairs")

    do {
      var requester = try PairingHandshake.begin(
        role: .requester, offer: try makeOffer(profiles: everyProfile),
        candidateIdentifier: "stream-1", localKeys: PairKeyMaterial(),
        deadline: try PairingOfferDeadline(
          offer: try makeOffer(profiles: everyProfile), startedAtMilliseconds: 0),
        nowMilliseconds: 0)
      var frame = try requester.writeMessage()
      frame[frame.startIndex] ^= 0xff
      var proxy = try PairingHandshake.begin(
        role: .proxy, offer: ceremonyOffer, candidateIdentifier: "stream-1",
        localKeys: PairKeyMaterial(),
        deadline: try PairingOfferDeadline(
          offer: ceremonyOffer, startedAtMilliseconds: 0), nowMilliseconds: 0)
      try proxy.readMessage(frame)
      check(false, "a tampered handshake frame is rejected")
    } catch PairingError.noise {
      check(true, "a tampered handshake frame is rejected")
    } catch {
      check(false, "a tampered handshake frame is rejected")
    }

    // A session may be entered only from the matching stored role.
    do {
      _ = try SessionHandshake.beginProxy(pair: peers.requester)
      check(false, "the proxy side refuses a requester's record")
    } catch SessionError.roleViolation {
      check(true, "the proxy side refuses a requester's record")
    } catch {
      check(false, "the proxy side refuses a requester's record")
    }

    // A frame that fails to decrypt is unattributable: the session ends, the
    // pairing does not.
    do {
      var requesterHandshake = try SessionHandshake.beginRequester(
        pair: peers.requester, intent: ExplicitUserIntent())
      var proxyHandshake = try SessionHandshake.beginProxy(pair: peers.proxy)
      try proxyHandshake.readMessage(try requesterHandshake.writeMessage())
      try requesterHandshake.readMessage(try proxyHandshake.writeMessage())
      var requesterAuthentication = try requesterHandshake.intoAuthentication()
      var proxyAuthentication = try proxyHandshake.intoAuthentication()
      var tampered = try requesterAuthentication.sendReady(nonce: randomBytes(FlowLimit.readyNonce))
      tampered[tampered.startIndex] ^= 0xff
      try proxyAuthentication.receiveReady(tampered)
      check(false, "a frame that fails to decrypt ends only the session")
    } catch SessionError.integrityFailure {
      check(true, "a frame that fails to decrypt ends only the session")
    } catch {
      check(false, "a frame that fails to decrypt ends only the session")
    }

    // A repeated ready is attributable to the peer, so it ends the pairing
    // rather than only the session.
    do {
      var requesterHandshake = try SessionHandshake.beginRequester(
        pair: peers.requester, intent: ExplicitUserIntent())
      var proxyHandshake = try SessionHandshake.beginProxy(pair: peers.proxy)
      try proxyHandshake.readMessage(try requesterHandshake.writeMessage())
      try requesterHandshake.readMessage(try proxyHandshake.writeMessage())
      var requesterAuthentication = try requesterHandshake.intoAuthentication()
      var proxyAuthentication = try proxyHandshake.intoAuthentication()
      let ready = try requesterAuthentication.sendReady(nonce: randomBytes(FlowLimit.readyNonce))
      try proxyAuthentication.receiveReady(ready)
      try proxyAuthentication.receiveReady(ready)
      check(false, "a repeated ready ends the pairing")
    } catch SessionError.pairingMustEnd(let cause) {
      check(cause == .duplicateReady, "a repeated ready ends the pairing")
    } catch {
      check(false, "a repeated ready ends the pairing")
    }

    // The candidate identifier is echoed but not bound into the prologue, so
    // only the ready comparison can catch a disagreement about it.
    do {
      let divergent = try PairRecord(
        pairIdentifier: peers.proxy.pairIdentifier,
        rendezvousToken: peers.proxy.rendezvousToken,
        role: .proxy,
        localStaticPrivate: peers.proxy.localStaticPrivate,
        localStaticPublic: peers.proxy.localStaticPublic,
        remoteStaticPublic: peers.proxy.remoteStaticPublic,
        grantsHash: peers.proxy.grantsHash,
        profiles: peers.proxy.profiles,
        transport: PairTransportBinding(
          profile: peers.proxy.transport.profile, candidateIdentifier: "other-1"),
        createdAtMilliseconds: peers.proxy.createdAtMilliseconds)
      var requesterHandshake = try SessionHandshake.beginRequester(
        pair: peers.requester, intent: ExplicitUserIntent())
      var proxyHandshake = try SessionHandshake.beginProxy(pair: divergent)
      try proxyHandshake.readMessage(try requesterHandshake.writeMessage())
      try requesterHandshake.readMessage(try proxyHandshake.writeMessage())
      var requesterAuthentication = try requesterHandshake.intoAuthentication()
      var proxyAuthentication = try proxyHandshake.intoAuthentication()
      try proxyAuthentication.receiveReady(
        try requesterAuthentication.sendReady(nonce: randomBytes(FlowLimit.readyNonce)))
      check(false, "a mismatched parameter echo ends the pairing")
    } catch SessionError.pairingMustEnd(let cause) {
      check(cause == .parameterMismatch, "a mismatched parameter echo ends the pairing")
    } catch {
      check(false, "a mismatched parameter echo ends the pairing")
    }

    // A session is not healthy until both echoes verify.
    do {
      var requesterHandshake = try SessionHandshake.beginRequester(
        pair: peers.requester, intent: ExplicitUserIntent())
      var proxyHandshake = try SessionHandshake.beginProxy(pair: peers.proxy)
      try proxyHandshake.readMessage(try requesterHandshake.writeMessage())
      try requesterHandshake.readMessage(try proxyHandshake.writeMessage())
      let requesterAuthentication = try requesterHandshake.intoAuthentication()
      _ = try requesterAuthentication.intoEstablished()
      check(false, "a session is not healthy before both echoes verify")
    } catch SessionError.readyIncomplete {
      check(true, "a session is not healthy before both echoes verify")
    } catch {
      check(false, "a session is not healthy before both echoes verify")
    }

    // MARK: - Negative control

    do {
      let offerA = try makeOffer(profiles: everyProfile)
      let offerB = try makeOffer(profiles: everyProfile)
      var requester = try PairingHandshake.begin(
        role: .requester, offer: offerA, candidateIdentifier: "stream-1",
        localKeys: PairKeyMaterial(),
        deadline: try PairingOfferDeadline(offer: offerA, startedAtMilliseconds: 0),
        nowMilliseconds: 0)
      var proxy = try PairingHandshake.begin(
        role: .proxy, offer: offerB, candidateIdentifier: "stream-1",
        localKeys: PairKeyMaterial(),
        deadline: try PairingOfferDeadline(offer: offerB, startedAtMilliseconds: 0),
        nowMilliseconds: 0)
      try proxy.readMessage(try requester.writeMessage())
      try requester.readMessage(try proxy.writeMessage())
      try proxy.readMessage(try requester.writeMessage())
      check(false, "a different pairing secret cannot complete the handshake")
    } catch PairingError.noise {
      check(true, "a different pairing secret cannot complete the handshake")
    } catch {
      check(false, "a different pairing secret cannot complete the handshake")
    }
  }
}
