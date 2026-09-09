// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The JSON SCS surface end to end over a scripted backend: version,
/// sign, and the specified refusals - every sign outcome as an HTTP
/// 200 whose JSON reason triple carries the result (DVV SCS
/// specification v1.3 §2.5-2.6, §3).
@Suite
internal struct ScsDispatcherTests {
  private static let origin = "https://dvv.fineid.fi"

  private func backend() -> ScriptedScsBackend {
    ScriptedScsBackend(
      chain: [Data([0x30, 0x03, 0x02, 0x01, 0x07])],
      algorithm: .rsa,
      signature: Data(repeating: 0xAB, count: 384)
    )
  }

  private func dispatch(
    method: String,
    path: String,
    contentType: String?,
    body: Data,
    backend: ScriptedScsBackend
  ) -> (status: String, json: [String: Any]) {
    let request = ScsHttpRequest(
      method: method,
      path: path,
      origin: Self.origin,
      contentType: contentType,
      bodyLength: body.count
    )
    let response = ScsDispatcher.dispatch(
      request: request,
      body: body,
      backend: backend,
      transactions: ScsTransactionManager()
    )
    let text = String(data: response, encoding: .utf8) ?? ""
    let statusLine = text.components(separatedBy: "\r\n").first ?? ""
    let bodyText = text.components(separatedBy: "\r\n\r\n").last ?? ""
    let json =
      (try? JSONSerialization.jsonObject(with: Data(bodyText.utf8))) as? [String: Any] ?? [:]
    return (statusLine, json)
  }

  private func signBody(
    content: Data,
    contentType: String,
    keyusages: [String]
  ) -> Data {
    let document = ScsSignRequestDocument(
      content: content.base64EncodedString(),
      contentType: contentType,
      selector: keyusages.isEmpty
        ? nil
        : ScsSignRequestDocument.Selector(keyusages: keyusages),
      hashAlgorithm: nil,
      signatureType: nil
    )
    return (try? JSONEncoder().encode(document)) ?? Data()
  }

  private func challenge() -> Data {
    Data("\(Self.origin);\(String(repeating: "a1b2c3d4", count: 8))".utf8)
  }

  @Test
  internal func versionDescribesTheSurface() {
    let (status, json) = dispatch(
      method: "GET", path: "/version", contentType: nil, body: Data(), backend: backend())
    #expect(status == "HTTP/1.1 200 OK")
    #expect(json["version"] as? String == "1.3")
    #expect(json["signatureTypes"] as? String == "signature,cms-pades")
    #expect(json["hashAlgorithms"] as? String == "SHA256,SHA384,SHA512")
    #expect(json["selectorAvailable"] as? Bool == true)
  }

  @Test
  internal func authenticationSignAnswersSignatureAndChain() {
    let scripted = backend()
    let (status, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: signBody(content: challenge(), contentType: "data", keyusages: []),
      backend: scripted
    )
    #expect(status == "HTTP/1.1 200 OK")
    #expect(json["status"] as? String == "ok")
    #expect(json["signatureAlgorithm"] as? String == "SHA256withRSA")
    #expect((json["chain"] as? [String])?.count == 1)
    #expect(
      json["signature"] as? String
        == Data(repeating: 0xAB, count: 384).base64EncodedString())
    #expect(scripted.signedPurposes == [.authentication])
    #expect(scripted.signedData == [challenge()])
  }

  @Test
  internal func qualifiedSelectorSkipsTheChallengeRule() {
    let scripted = backend()
    let (_, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: signBody(
        content: Data("free-form document".utf8),
        contentType: "data",
        keyusages: ["nonRepudiation"]
      ),
      backend: scripted
    )
    #expect(json["status"] as? String == "ok")
    #expect(scripted.signedPurposes == [.qualified])
  }

  @Test
  internal func unboundAuthenticationContentIsForbidden() {
    let (status, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: signBody(
        content: Data("arbitrary bytes".utf8), contentType: "data", keyusages: []),
      backend: backend()
    )
    #expect(status == "HTTP/1.1 200 OK")
    #expect(json["status"] as? String == "failed")
    #expect(json["reasonCode"] as? Int == 403)
  }

  @Test
  internal func digestContentIsNotImplemented() {
    let (_, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: signBody(content: challenge(), contentType: "digest", keyusages: []),
      backend: backend()
    )
    #expect(json["status"] as? String == "failed")
    #expect(json["reasonCode"] as? Int == 501)
  }

  @Test
  internal func malformedJsonAnswersBadRequest() {
    let (status, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: Data("not json".utf8),
      backend: backend()
    )
    #expect(status == "HTTP/1.1 200 OK")
    #expect(json["reasonCode"] as? Int == 400)
  }

  @Test
  internal func credentialRefusalAnswersUnauthorized() {
    let scripted = backend()
    scripted.refusal = .credentialRefused("PIN entry was cancelled")
    let (_, json) = dispatch(
      method: "POST",
      path: "/sign",
      contentType: "application/json",
      body: signBody(content: challenge(), contentType: "data", keyusages: []),
      backend: scripted
    )
    #expect(json["status"] as? String == "failed")
    #expect(json["reasonCode"] as? Int == 401)
  }

  @Test
  internal func unknownRouteAnswersNotFound() {
    let (status, _) = dispatch(
      method: "GET", path: "/nowhere", contentType: nil, body: Data(), backend: backend())
    #expect(status == "HTTP/1.1 404 Not Found")
  }
}
