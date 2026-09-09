// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
//
// Replays the operation-protocol bodies emitted by the reference engine.
// Every body is produced through the engine's own encoders rather than
// assembled here, so the test proves what a peer would actually receive.

import Foundation
import Testing

@testable import RappEngine

@Suite("RAPP operation bodies against the vendored bytes")
internal struct OperationBodyTests {
  /// One typed request and the vector it must reproduce.
  private struct RequestCase {
    let name: String
    let profile: ProfileName
    let operation: CardOperation
  }

  private static func expected(_ corpus: OperationCorpus, _ name: String) throws -> String {
    guard let vector = corpus.vectors.first(where: { $0.name == name }) else {
      throw CorpusError.missingHandshake(name: name)
    }
    return vector.bodyHex
  }

  private static func reference(_ inputs: OperationInputs) throws -> OperationReference {
    OperationReference(
      operationIdentifier: try Data(hex: inputs.operationIdentifierReference),
      requestHash: try Data(hex: inputs.requestHashReference))
  }

  /// Every request shares its identifiers; only the typed operation differs.
  private static func request(
    _ inputs: OperationInputs, _ profile: ProfileName, _ operation: CardOperation
  ) throws -> OperationRequest {
    try OperationRequest(
      operationIdentifier: try Data(hex: inputs.operationIdentifierRequest),
      pairIdentifier: try Data(hex: inputs.pairIdentifier),
      sessionIdentifier: try Data(hex: inputs.sessionIdentifier),
      profile: profile,
      localStartMilliseconds: inputs.localStartMilliseconds,
      expiresAfterMilliseconds: inputs.expiresAfterMilliseconds,
      operation: operation)
  }

  private static func encoded(_ message: TypedMessage) throws -> String {
    guard let body = try message.encodedBody() else {
      throw CorpusError.missingHandshake(name: "encodable body")
    }
    return body.hex
  }

  @Test("The vendored bodies are the current revision")
  internal func vectorIdentity() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    #expect(corpus.format == "fi.refineid.rapp.operation-vectors-v1")
    #expect(corpus.protocolDocumentVersion == "26.9.7.70")
    #expect(corpus.vectors.count == 30)
  }

  @Test("Every typed request matches the reference engine byte for byte")
  internal func requestBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let inputs = corpus.fixedInputs
    let cases: [RequestCase] = [
      RequestCase(name: "request-inspect-card", profile: .cardStatus, operation: .inspectCard),
      RequestCase(name: "request-read-identity", profile: .cardStatus, operation: .readIdentity),
      RequestCase(
        name: "request-read-certificate-authentication", profile: .authentication,
        operation: .readCertificate(kind: .authentication)),
      RequestCase(
        name: "request-read-certificate-signature", profile: .documentSigning,
        operation: .readCertificate(kind: .signature)),
      RequestCase(
        name: "request-browser-authenticate", profile: .authentication,
        operation: .browserAuthenticate(
          origin: inputs.origin, keyProfile: .rsa3072, algorithm: .rsaPkcs1Sha256,
          digest: try Data(hex: inputs.digestSha256))),
      RequestCase(
        name: "request-sign-document", profile: .documentSigning,
        operation: .signDocument(
          documentName: inputs.documentName, keyProfile: .ecdsaP384, algorithm: .ecdsaSha384,
          digest: try Data(hex: inputs.digestSha384))),
    ]
    for testCase in cases {
      let message = TypedMessage.operationRequest(
        try Self.request(inputs, testCase.profile, testCase.operation))
      #expect(
        try Self.encoded(message) == (try Self.expected(corpus, testCase.name)), "\(testCase.name)")
    }

  }

  @Test("Prepared, commit, and the acknowledgement share one reference body")
  internal func referenceBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let reference = try Self.reference(corpus.fixedInputs)
    let cases: [(String, TypedMessage)] = [
      ("prepared", .operationPrepared(reference)),
      ("commit", .operationCommit(reference)),
      ("result-ack", .operationResultAck(reference)),
    ]
    for (name, message) in cases {
      #expect(try Self.encoded(message) == (try Self.expected(corpus, name)), "\(name)")
    }
    #expect(
      try Self.expected(corpus, "prepared") == (try Self.expected(corpus, "commit")))
    #expect(
      try Self.expected(corpus, "commit") == (try Self.expected(corpus, "result-ack")))
  }

  @Test("A cancellation carries free text the registry could not express")
  internal func cancelBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let reference = try Self.reference(corpus.fixedInputs)
    let withReason = TypedMessage.operationCancel(
      CancelMessage(reference: reference, reason: corpus.fixedInputs.cancelReason))
    #expect(
      try Self.encoded(withReason) == (try Self.expected(corpus, "cancel-with-reason")))
    let bare = TypedMessage.operationCancel(CancelMessage(reference: reference, reason: nil))
    #expect(try Self.encoded(bare) == (try Self.expected(corpus, "cancel-without-reason")))
  }

  @Test("A status request and every status report match byte for byte")
  internal func statusBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let inputs = corpus.fixedInputs
    let identifier = try Data(hex: inputs.operationIdentifierStatus)
    let requestHash = try Data(hex: inputs.requestHashStatus)

    #expect(
      try Self.encoded(.operationStatusRequest(operationIdentifier: identifier))
        == (try Self.expected(corpus, "status-request")))

    let cases: [(String, OperationState)] = [
      ("status-known-completed", .completed),
      ("status-known-ambiguous", .ambiguous),
    ]
    for (name, state) in cases {
      let report = StatusReport(
        operationIdentifier: identifier, known: true, state: state, requestHash: requestHash)
      #expect(
        try Self.encoded(.operationStatus(report)) == (try Self.expected(corpus, name)), "\(name)")
    }

    let unknown = StatusReport(
      operationIdentifier: identifier, known: false, state: nil, requestHash: nil)
    #expect(
      try Self.encoded(.operationStatus(unknown))
        == (try Self.expected(corpus, "status-unknown")))
  }

  @Test("An unknown status omits its absent fields rather than nulling them")
  internal func unknownStatusOmitsFields() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let unknown = StatusReport(
      operationIdentifier: try Data(hex: corpus.fixedInputs.operationIdentifierStatus),
      known: false, state: nil, requestHash: nil)
    #expect(unknown.wireBody.count == 2)
  }

  @Test("Each registered protocol error matches byte for byte")
  internal func errorBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let identifier = try Data(hex: corpus.fixedInputs.operationIdentifierError)
    let cases: [(String, ProtocolErrorMessage)] = [
      ("error-busy", .busy),
      ("error-unknown-operation-with-id", .unknownOperation(operationIdentifier: identifier)),
      ("error-unknown-operation-bare", .unknownOperation(operationIdentifier: nil)),
    ]
    for (name, error) in cases {
      #expect(try Self.encoded(.error(error)) == (try Self.expected(corpus, name)), "\(name)")
    }
  }

  @Test("Every completed result matches byte for byte and decodes back")
  internal func completedResultBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let inputs = corpus.fixedInputs
    let reference = try Self.reference(inputs)
    let inspection = inputs.inspection
    let cases: [(String, CardOperationResult)] = [
      (
        "result-completed-inspection",
        .inspection(
          CardInspection(
            pin1Factory: inspection.pin1Factory, pin2Factory: inspection.pin2Factory,
            pin1Attempts: inspection.pin1Attempts, pin2Attempts: inspection.pin2Attempts,
            pukAttempts: inspection.pukAttempts))
      ),
      (
        "result-completed-identity",
        .identity(displayName: inputs.displayName, personIdentifier: inputs.personIdentifier)
      ),
      ("result-completed-certificate", .certificate(try Data(hex: inputs.certificateDer))),
      ("result-completed-signature", .signature(try Data(hex: inputs.signatureBytes))),
    ]
    for (name, result) in cases {
      let message = OperationResultMessage.completed(reference: reference, result: result)
      #expect(try message.encoded().hex == (try Self.expected(corpus, name)), "\(name)")
      let decoded = try OperationResultMessage.decode(
        try Data(hex: try Self.expected(corpus, name)))
      #expect(decoded == message, "\(name) decodes from the reference bytes")
    }
  }

  @Test("Every registered failure matches byte for byte and decodes back")
  internal func failureResultBodies() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let reference = try Self.reference(corpus.fixedInputs)
    let cases: [(String, ResultError)] = [
      ("result-denied-user-denied", .userDenied),
      ("result-cancelled-request-expired", .requestExpired),
      ("result-cancelled-cancelled", .cancelled),
      ("result-cancelled-card-removed", .cardRemovedBeforeTransmit),
      ("result-rejected-invalid", .requestInvalidOrUnsupported),
      ("result-rejected-retry-policy", .retryPolicyRefused),
      ("result-credential-rejected", .credentialRejected),
      ("result-ambiguous-completion", .cardCompletionAmbiguous),
    ]
    for (name, error) in cases {
      let message = OperationResultMessage.failure(reference: reference, error: error)
      #expect(try message.encoded().hex == (try Self.expected(corpus, name)), "\(name)")
      let decoded = try OperationResultMessage.decode(
        try Data(hex: try Self.expected(corpus, name)))
      #expect(decoded == message, "\(name) decodes from the reference bytes")
    }
  }

  @Test("A changed digest changes the request bytes")
  internal func changedDigestChangesTheBytes() throws {
    let corpus = try CorpusFile.operation(filePath: #filePath)
    let inputs = corpus.fixedInputs
    var digest = try Data(hex: inputs.digestSha256)
    let first = try #require(digest.indices.first)
    digest[first] ^= 1
    let altered = TypedMessage.operationRequest(
      try Self.request(
        inputs, .authentication,
        .browserAuthenticate(
          origin: inputs.origin, keyProfile: .rsa3072, algorithm: .rsaPkcs1Sha256,
          digest: digest)))
    #expect(
      try Self.encoded(altered) != (try Self.expected(corpus, "request-browser-authenticate")))
  }
}
