// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation
import Testing

/// The JOSE pieces under the SCS transaction: base64url and the
/// direct-encryption A256GCM JWE (RFC 7515 section 2, RFC 7516).
@Suite
internal struct ScsJoseTests {
  @Test
  internal func base64UrlRoundTripsWithoutPadding() {
    let bytes = Data([0xFB, 0xEF, 0x00, 0x01, 0x02])
    let encoded = Base64Url.encode(bytes)
    #expect(!encoded.contains("="))
    #expect(!encoded.contains("+"))
    #expect(!encoded.contains("/"))
    #expect(Base64Url.decode(encoded) == bytes)
  }

  @Test
  internal func jweRoundTripsUnderTheSameKey() throws {
    let key = SymmetricKey(size: .bits256)
    let plaintext = Data("attribute bytes".utf8)
    let sealed = ScsJsonWebEncryption.encrypt(plaintext: plaintext, key: key)
    let compact = try sealed.get()
    let segments = compact.components(separatedBy: ".")
    #expect(segments.count == 5)
    #expect(segments[1].isEmpty)
    let openedOutcome = ScsJsonWebEncryption.decrypt(
      compact: Data(compact.utf8), key: key)
    let opened = try openedOutcome.get()
    #expect(opened == plaintext)
  }

  @Test
  internal func jweRefusesTheWrongKey() throws {
    let sealed = ScsJsonWebEncryption.encrypt(
      plaintext: Data("secret".utf8), key: SymmetricKey(size: .bits256))
    let compact = try sealed.get()
    let outcome = ScsJsonWebEncryption.decrypt(
      compact: Data(compact.utf8), key: SymmetricKey(size: .bits256))
    guard case .failure(let error) = outcome else {
      Issue.record("expected an authentication failure")
      return
    }
    #expect(error.code == 403)
  }

  @Test
  internal func jweRefusesAForeignHeader() {
    let header = Base64Url.encode(Data(#"{"alg":"RSA-OAEP","enc":"A256GCM"}"#.utf8))
    let outcome = ScsJsonWebEncryption.decrypt(
      compact: Data("\(header)..AAAA.AAAA.AAAA".utf8),
      key: SymmetricKey(size: .bits256)
    )
    guard case .failure(let error) = outcome else {
      Issue.record("expected a refusal")
      return
    }
    #expect(error.code == 400)
  }
}
