// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation
import Security
import Testing

/// The localhost server certificate the SCS presents (DVV SCS
/// specification v1.3 §2.3).
///
/// The browser checks these attributes before it will talk to the
/// local service at all, and a malformed certificate fails as an
/// opaque TLS handshake error, so the shape is asserted here rather
/// than discovered on a connection.
@Suite
internal struct ScsLocalhostCertificateTests {
  /// One DER element at `offset`: its whole range and its content.
  ///
  /// Short and long definite forms only, which is all a certificate
  /// uses.
  private static func element(
    in der: Data,
    at offset: Data.Index
  ) -> (raw: Range<Data.Index>, content: Range<Data.Index>)? {
    guard offset + 2 <= der.endIndex else { return nil }
    let lengthByte = der[offset + 1]
    var contentStart = offset + 2
    var length = Int(lengthByte)
    if lengthByte & 0x80 != 0 {
      let countOfLengthBytes = Int(lengthByte & 0x7F)
      guard countOfLengthBytes > 0, contentStart + countOfLengthBytes <= der.endIndex else {
        return nil
      }
      length = der[contentStart..<contentStart + countOfLengthBytes]
        .reduce(0) { total, byte in total << 8 | Int(byte) }
      contentStart += countOfLengthBytes
    }
    let contentEnd = contentStart + length
    guard contentEnd <= der.endIndex else { return nil }
    return (offset..<contentEnd, contentStart..<contentEnd)
  }

  /// One built certificate over a fresh P-256 key.
  private func certificate() -> (der: Data, key: P256.Signing.PrivateKey) {
    let key = P256.Signing.PrivateKey()
    let spki = ScsLocalhostCertificate.subjectPublicKeyInfo(
      fromX963: key.publicKey.x963Representation)
    let der = ScsLocalhostCertificate.make(
      subjectPublicKeyInfo: spki,
      serialNumber: Data([0x01, 0x02, 0x03, 0x04]),
      from: Date()
    ) { tbs in
      (try? key.signature(for: tbs))?.derRepresentation ?? Data()
    }
    return (der, key)
  }

  @Test
  internal func theSystemParsesTheCertificate() throws {
    // Security.framework is the consumer that matters: it must both
    // parse the certificate and recover its public key.
    let built = certificate()
    let parsed = try #require(
      SecCertificateCreateWithData(nil, built.der as CFData))
    let publicKey = try #require(SecCertificateCopyKey(parsed))
    let representation = try #require(
      SecKeyCopyExternalRepresentation(publicKey, nil) as Data?)
    #expect(representation == built.key.publicKey.x963Representation)
  }

  @Test
  internal func theSubjectIsTheLoopbackAddress() throws {
    let built = certificate()
    let parsed = try #require(
      SecCertificateCreateWithData(nil, built.der as CFData))
    var commonName: CFString?
    _ = SecCertificateCopyCommonName(parsed, &commonName)
    #expect(commonName as String? == "127.0.0.1")
  }

  @Test
  internal func theCertificateIsSelfIssuedAndCurrentlyValid() throws {
    let built = certificate()
    let facts = try #require(CertificateFacts(der: built.der))
    #expect(facts.isSelfIssued)
    // The validity window opens at creation and runs for years, so
    // the certificate a fresh install builds is usable now.
    let trust = try #require(
      SecCertificateCreateWithData(nil, built.der as CFData))
    var evaluation: SecTrust?
    let policy = SecPolicyCreateSSL(true, "localhost" as CFString)
    #expect(
      SecTrustCreateWithCertificates(trust, policy, &evaluation) == errSecSuccess)
  }

  @Test
  internal func theSignatureCoversTheCertificateBody() throws {
    // The signature must verify against the key inside: a browser
    // rejects a self-signed certificate whose own signature does
    // not check out.
    let built = certificate()
    let outer = try #require(Self.element(in: built.der, at: built.der.startIndex))
    var cursor = outer.content.lowerBound
    let tbs = try #require(Self.element(in: built.der, at: cursor))
    cursor = tbs.raw.upperBound
    let algorithm = try #require(Self.element(in: built.der, at: cursor))
    cursor = algorithm.raw.upperBound
    let signatureBits = try #require(Self.element(in: built.der, at: cursor))
    // A BIT STRING's first content octet counts unused trailing bits.
    let signature = try P256.Signing.ECDSASignature(
      derRepresentation: Data(built.der[signatureBits.content].dropFirst()))
    #expect(
      built.key.publicKey.isValidSignature(signature, for: built.der[tbs.raw]))
  }
}
