// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import PKCS11Bridge
import Testing

@Suite
internal struct RsaEncodingTests {
  /// SEQUENCE { INTEGER 0x00ABCDEF, INTEGER 0x03 }, the shape
  /// SecKeyCopyExternalRepresentation returns for an RSA key.
  private let externalKey = Data([
    0x30, 0x09,
    0x02, 0x04, 0x00, 0xAB, 0xCD, 0xEF,
    0x02, 0x01, 0x03,
  ])

  /// The DigestInfo prefix OpenSSH builds for a SHA-256 digest.
  private let sha256Prefix = Data([
    0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03,
    0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ])

  private let sha256DigestLength = 32

  @Test
  internal func readsModulusAndExponent() throws {
    let parsed = try #require(RsaEncoding.publicKey(fromExternal: externalKey))
    #expect(parsed.modulus == Data([0xAB, 0xCD, 0xEF]))
    #expect(parsed.exponent == Data([0x03]))
  }

  @Test
  internal func rejectsMalformedPublicKeys() {
    #expect(RsaEncoding.publicKey(fromExternal: Data()) == nil)
    #expect(RsaEncoding.publicKey(fromExternal: externalKey.dropLast()) == nil)
    #expect(RsaEncoding.publicKey(fromExternal: externalKey.dropFirst()) == nil)
  }

  @Test
  internal func readsDigestAndAlgorithmFromDigestInfo() throws {
    let digest = Data(repeating: 0x5A, count: sha256DigestLength)
    let parsed = try #require(RsaEncoding.digest(fromDigestInfo: sha256Prefix + digest))
    #expect(parsed.value == digest)
    #expect(parsed.algorithm == .rsaSignatureDigestPKCS1v15SHA256)
  }

  @Test
  internal func rejectsMalformedDigestInfo() {
    let digest = Data(repeating: 0x5A, count: sha256DigestLength)
    #expect(RsaEncoding.digest(fromDigestInfo: digest) == nil)
    #expect(RsaEncoding.digest(fromDigestInfo: sha256Prefix) == nil)
    #expect(RsaEncoding.digest(fromDigestInfo: sha256Prefix + digest.dropLast()) == nil)

    // A DigestInfo naming an algorithm the bridge does not map.
    var unknownOid = sha256Prefix
    unknownOid[14] = 0x09
    #expect(RsaEncoding.digest(fromDigestInfo: unknownOid + digest) == nil)
  }
}
