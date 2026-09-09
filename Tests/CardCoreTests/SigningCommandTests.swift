// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct SigningCommandTests {
  @Test
  internal func manageSecurityEnvironmentComposesTheAlgorithmReference() {
    // FINEID S1 v4.2 §3.6: MSE:SET DST, auth key (84 01 01). The
    // algorithm reference byte is hash-high-nibble | scheme-low-nibble.
    let vectors: [(SigningAlgorithm, String)] = [
      (SigningAlgorithm(hash: .sha384, scheme: .ecdsa), "54"),
      (SigningAlgorithm(hash: .sha256, scheme: .ecdsa), "44"),
      (SigningAlgorithm(hash: .sha224, scheme: .ecdsa), "34"),
      (SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1), "42"),
      (SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1), "52"),
      (SigningAlgorithm(hash: .sha256, scheme: .rsaPss), "45"),
    ]
    for (algorithm, referenceHex) in vectors {
      let command = CommandApdu.selectSigningEnvironment(
        algorithm: algorithm,
        key: .authentication
      )
      #expect(
        command.encoded == WireHex.data("002241B6068001\(referenceHex)840101")
      )
    }
  }

  @Test
  internal func manageSecurityEnvironmentNamesTheQualifiedKey() {
    // FINEID S1 v4.2 §3.6: MSE:SET DST for the PIN2-gated key (84 01 02).
    let command = CommandApdu.selectSigningEnvironment(
      algorithm: SigningAlgorithm(hash: .sha384, scheme: .ecdsa),
      key: .qualifiedSignature
    )
    #expect(command.encoded == WireHex.data("002241B606800154840102"))
  }

  @Test
  internal func rsaSha384NamesTheQualifiedKey() {
    let command = CommandApdu.selectSigningEnvironment(
      algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
      key: .qualifiedSignature
    )
    #expect(command.encoded == WireHex.data("002241B606800152840102"))
  }

  @Test
  internal func performSignatureCarriesTheDigest() {
    // PSO:CDS: 00 2A 9E 9A <Lc> <digest> 00.
    let digest = String(repeating: "AB", count: 48)
    let command = CommandApdu.computeSignature(overDigest: WireHex.data(digest))
    #expect(command.encoded == WireHex.data("002A9E9A30" + digest + "00"))
  }

  @Test
  internal func performSignatureRetryUsesExactLength() throws {
    let digest = WireHex.data("AABB")
    let exact = try #require(ExpectedResponseLength(count: 96))
    let command = CommandApdu.computeSignature(
      overDigest: digest,
      exactLength: exact
    )
    // Le 0x60 = 96.
    #expect(command.encoded == WireHex.data("002A9E9A02AABB60"))
  }

  @Test
  internal func externalHashLoadsTheDigestInAHashValueObject() {
    // FINEID S1 v4.2 §3.7: PSO:HASH external, 00 2A 90 A0 <Lc> 90 <len>
    // <digest>. For SHA-384 the 48-byte digest wraps as 90 30 <48>, so
    // Lc = 0x32 (= 50).
    let digest = String(repeating: "CD", count: 48)
    let command = CommandApdu.loadExternalHash(WireHex.data(digest))
    #expect(command.encoded == WireHex.data("002A90A0329030" + digest))
  }

  @Test
  internal func loadedHashSignatureHasAnEmptyBody() {
    // FINEID S1 v4.2 §3.8: after PSO:HASH the signature is produced by
    // an empty PSO:CDS, 00 2A 9E 9A 00 (Le=00 requests the maximum).
    let command = CommandApdu.computeSignatureOverLoadedHash()
    #expect(command.encoded == WireHex.data("002A9E9A00"))
  }

  @Test
  internal func loadedHashSignatureRetryUsesExactLength() throws {
    let exact = try #require(ExpectedResponseLength(count: 96))
    let command = CommandApdu.computeSignatureOverLoadedHash(exactLength: exact)
    // Empty body, Le 0x60 = 96.
    #expect(command.encoded == WireHex.data("002A9E9A60"))
  }

  @Test
  internal func loadedHashSignatureEncodesTheFullShortResponse() throws {
    let exact = try #require(ExpectedResponseLength(count: 256))
    let command = CommandApdu.computeSignatureOverLoadedHash(exactLength: exact)
    #expect(command.encoded == WireHex.data("002A9E9A00"))
  }

  @Test
  internal func wrongLengthStatusCarriesTheAvailableLength() {
    let status = WireHex.statusWord("6C60")
    #expect(status == .wrongExpectedLength(availableLength: 96))
  }
}
