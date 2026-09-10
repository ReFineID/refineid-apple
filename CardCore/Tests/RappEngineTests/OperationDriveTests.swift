// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Typed operations, hash-bound approval, and at-most-once card safety

import Foundation
import Testing

@testable import RappEngine

// Known-answer harness for the operation layer. It drives the authorization
// transaction, its journal, and the state tables, and prints one line per
// check.

internal func check(_ name: String, _ condition: Bool) {
  #expect(condition, "\(name)")
}

internal func browserRequest() throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    origin: OperationFixture.origin,
    keyProfile: .ecdsaP256,
    algorithm: .ecdsaSha256,
    digest: OperationFixture.digest)
}

internal func browserRequest(origin: String) throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    origin: origin,
    keyProfile: .ecdsaP256,
    algorithm: .ecdsaSha256,
    digest: OperationFixture.digest)
}

internal func browserRequest(digest: Data) throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    origin: OperationFixture.origin,
    keyProfile: .ecdsaP256,
    algorithm: .ecdsaSha256,
    digest: digest)
}

internal func browserRequest(
  keyProfile: CardKeyProfile, algorithm: SignatureAlgorithm, digest: Data
) throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    origin: OperationFixture.origin,
    keyProfile: keyProfile,
    algorithm: algorithm,
    digest: digest)
}

internal func browserRequest(sessionIdentifier: Data) throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    sessionIdentifier: sessionIdentifier,
    origin: OperationFixture.origin,
    keyProfile: .ecdsaP256,
    algorithm: .ecdsaSha256,
    digest: OperationFixture.digest)
}

internal func browserRequest(operationIdentifier: Data) throws -> OperationRequest {
  try browserRequest(
    operationIdentifier: operationIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    origin: OperationFixture.origin,
    keyProfile: .ecdsaP256,
    algorithm: .ecdsaSha256,
    digest: OperationFixture.digest)
}

internal func browserRequest(  // swiftlint:disable:this function_parameter_count
  operationIdentifier: Data,
  sessionIdentifier: Data,
  origin: String,
  keyProfile: CardKeyProfile,
  algorithm: SignatureAlgorithm,
  digest: Data
) throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: sessionIdentifier,
    profile: .authentication,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: .browserAuthenticate(
      origin: origin, keyProfile: keyProfile, algorithm: algorithm, digest: digest))
}

internal func identityRequest() throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    profile: .cardStatus,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: .readIdentity)
}

/// Drives a consequential operation to the point where the card would act.
internal func executeToCard(
  _ transaction: inout AuthorizationTransaction, _ store: inout OperationJournalStore
) throws {
  try transaction.prerequisitesComplete()
  let approval = try UserApproval(
    for: transaction.request, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
  _ = try transaction.approve(
    approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
    maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
  try transaction.commit(
    to: &store, requesterCommit: transaction.reference,
    nowMilliseconds: OperationFixture.approvalMilliseconds,
    maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
}

internal func hexText(_ bytes: Data) -> String {
  bytes.map { String(format: "%02x", $0) }.joined()
}

internal func fixedRequest(
  profile: ProfileName, operation: CardOperation
) throws -> OperationRequest {
  try OperationRequest(
    operationIdentifier: OperationFixture.operationIdentifier,
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    profile: profile,
    localStartMilliseconds: OperationFixture.startMilliseconds,
    expiresAfterMilliseconds: OperationFixture.lifetimeMilliseconds,
    operation: operation)
}

/// 0. The registry agrees with the reference engine byte for byte
private func step0() throws {
  let browser = try fixedRequest(
    profile: .authentication,
    operation: .browserAuthenticate(
      origin: OperationFixture.origin, keyProfile: .ecdsaP256, algorithm: .ecdsaSha256,
      digest: OperationFixture.digest))
  check(
    "browser authentication hashes to the reference value",
    hexText(try browser.requestHash()) == ReferenceOperation.browserHash)
  check(
    "the browser request body is byte-exact",
    hexText(try WireValue.map(try browser.wireBody()).encoded())
      == ReferenceOperation.browserBody)

  let sign = try fixedRequest(
    profile: .documentSigning,
    operation: .signDocument(
      documentName: "Contract.pdf", keyProfile: .rsa3072, algorithm: .rsaPkcs1Sha256,
      digest: OperationFixture.digest))
  check(
    "document signing hashes to the reference value",
    hexText(try sign.requestHash()) == ReferenceOperation.signHash)

  let identity = try fixedRequest(profile: .cardStatus, operation: .readIdentity)
  check(
    "reading the identity hashes to the reference value",
    hexText(try identity.requestHash()) == ReferenceOperation.identityHash)

  let certificate = try fixedRequest(
    profile: .documentSigning, operation: .readCertificate(kind: .signature))
  check(
    "reading a certificate hashes to the reference value",
    hexText(try certificate.requestHash()) == ReferenceOperation.certificateHash)

  let inspect = try fixedRequest(profile: .cardStatus, operation: .inspectCard)
  check(
    "inspecting the card hashes to the reference value",
    hexText(try inspect.requestHash()) == ReferenceOperation.inspectHash)
}

/// 1. The request hash binds every field
private func step1() throws {
  // MARK: - 1. The request hash binds every field
  try hashBindsEveryField()
  try approvalDoesNotTravel()
  try wireBodyRoundTrip()
  try tamperedHashRefused()
}

/// The request hash binds every field.
private func hashBindsEveryField() throws {
  let base = try browserRequest()
  let baseHash = try base.requestHash()

  check(
    "changing the origin changes the hash",
    try browserRequest(origin: "https://other.test").requestHash() != baseHash)
  check(
    "changing the digest changes the hash",
    try browserRequest(digest: OperationFixture.otherDigest).requestHash() != baseHash)
  check(
    "changing the algorithm changes the hash",
    try browserRequest(
      keyProfile: .ecdsaP384, algorithm: .ecdsaSha384,
      digest: Data(repeating: OperationFill.digest, count: DigestLength.sha384)
    ).requestHash() != baseHash)
  check(
    "changing the session changes the hash",
    try browserRequest(sessionIdentifier: OperationFixture.otherSession).requestHash() != baseHash
  )
  check(
    "changing the operation identifier changes the hash",
    try browserRequest(operationIdentifier: OperationFixture.otherOperation).requestHash()
      != baseHash)
  check("the same request hashes the same", try browserRequest().requestHash() == baseHash)
}

/// An approval names the hash it approved, so it cannot travel.
private func approvalDoesNotTravel() throws {
  let base = try browserRequest()
  let approval = try UserApproval(
    for: base, approvedAtMilliseconds: OperationFixture.approvalMilliseconds)
  var other = try AuthorizationTransaction(
    request: try browserRequest(digest: OperationFixture.otherDigest))
  try other.prerequisitesComplete()
  var moved = false
  do {
    _ = try other.approve(
      approval, nowMilliseconds: OperationFixture.approvalMilliseconds,
      maximumLifetimeMilliseconds: OperationFixture.maximumLifetimeMilliseconds)
    moved = true
  } catch AuthorizationError.approvalMismatch {
    moved = false
  }
  check("an approval does not authorize a different request", !moved)
}

/// The wire body carries the hash, and a receiver recomputes it.
private func wireBodyRoundTrip() throws {
  let base = try browserRequest()
  let parsed = try OperationRequest.from(
    wireBody: try base.wireBody(),
    pairIdentifier: OperationFixture.pairIdentifier,
    sessionIdentifier: OperationFixture.sessionIdentifier,
    localStartMilliseconds: OperationFixture.startMilliseconds)
  check("a request round-trips through its wire body", parsed == base)
}

/// A request whose hash does not cover it is refused.
private func tamperedHashRefused() throws {
  let base = try browserRequest()
  var tampered = try base.wireBody()
  tampered["request_hash"] = .bytes(
    Data(repeating: OperationFill.tamperedHash, count: OperationSize.requestHash))
  var acceptedTamper = false
  do {
    _ = try OperationRequest.from(
      wireBody: tampered, pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      localStartMilliseconds: OperationFixture.startMilliseconds)
    acceptedTamper = true
  } catch CardOperationError.requestHashMismatch {
    acceptedTamper = false
  }
  check("a request whose hash does not cover it is refused", !acceptedTamper)
}

/// 5. Credential rejection through the state tables
private func step5() throws {
  // MARK: - 5. Credential rejection through the state tables
  do {
    var state = RappState(role: .proxy)
    state.pairing = .pairedConnected
    state.session = .healthy
    state.operation = .executing

    let outcome = state.credentialRejected()
    check("the operation ends as credential rejected", state.operation == .credentialRejected)
    check("the session leaves healthy", state.session != .healthy)
    check(
      "the pair is revoked after a credential rejection",
      outcome.actions.contains(.revokePairAfterCredentialRejection))
    check(
      "the rejected credential and its derived state are removed",
      outcome.actions.contains(.removeRejectedCredentialAndDerivedState))
    check("a fresh explicit user action is required", state.requiresUserIntent)

    // The same rejection travels through the authorization transaction.
    var store = OperationJournalStore()
    var transaction = try AuthorizationTransaction(request: try browserRequest())
    try executeToCard(&transaction, &store)
    let pending = try transaction.beginCardCommand(to: &store)
    _ = pending.execute { $0 }
    let rejected = OperationResultMessage.failure(
      reference: transaction.reference, error: .credentialRejected)
    try transaction.finishFailure(to: &store, result: rejected)
    check(
      "a credential rejection is a terminal operation state",
      transaction.operationState == .credentialRejected)
    check(
      "a credential rejection forbids automatic retry",
      store.writes.last?.automaticRetryPermitted == false)
  }
}

/// Negative control.
private func step7() throws {
  // MARK: - Negative control
  do {
    // Permitting a second transmission must break the at-most-once check, so
    // the harness is shown to be measuring something.
    var store = OperationJournalStore()
    var journal = OperationJournal(
      pairIdentifier: OperationFixture.pairIdentifier,
      sessionIdentifier: OperationFixture.sessionIdentifier,
      operationIdentifier: OperationFixture.operationIdentifier,
      requestHash: try browserRequest().requestHash())
    try journal.commit(to: &store, requestHash: try browserRequest().requestHash())
    let first = try journal.beginCardCommand(to: &store, command: "one-shot")
    _ = first.execute { $0 }

    // Rewind the durable record to committed, which is what a broken
    // implementation that forgot the transmission count would leave behind.
    var rewound = OperationJournal(
      recovered: ProxyJournalRecord(
        pairIdentifier: OperationFixture.pairIdentifier,
        sessionIdentifier: OperationFixture.sessionIdentifier,
        operationIdentifier: OperationFixture.operationIdentifier,
        requestHash: try browserRequest().requestHash(),
        state: .committed,
        transmissionCount: TransmissionCount.untransmitted,
        automaticRetryPermitted: true))
    let second = try rewound.beginCardCommand(to: &store, command: "one-shot")
    _ = second.execute { $0 }
    check(
      "a rewound record would transmit twice, so the check is real",
      store.writes.filter { record in record.state == .executing }.count
        == OperationFill.expectedExecutingWrites)
  }
}

// The scenario runs as one continuous drive, because that is what it proves:
// each step depends on the state the previous one left, and a peer answers a
// real predecessor rather than a fixture. Splitting it into separate tests
// would thread that state through setup and stop testing the sequence.
@Suite("RAPP operations and authorization")
internal struct OperationDriveTests {
  @Test("Typed operations, hash-bound approval, and at-most-once card safety")
  internal func run() throws {
    try step0()
    try step1()
    try step2()
    try step3()
    try step4()
    try step5()
    try step6()
    try step7()
  }
}
