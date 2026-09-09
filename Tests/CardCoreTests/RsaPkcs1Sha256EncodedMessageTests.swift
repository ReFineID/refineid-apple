// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct RsaPkcs1Sha256EncodedMessageTests {
  /// A recognizable but wholly synthetic SHA-256-sized value.
  private static let syntheticDigest = Data((0..<32).map(UInt8.init))

  /// Fixed EMSA-PKCS1-v1_5 SHA-256 DigestInfo prefix.
  private static let digestInfoPrefix: [UInt8] = [
    0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
    0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ]

  /// Builds one exact modulus-wide encoded message without card data.
  private static func validBlock(_ profile: CardKeyProfile) -> Data {
    let trailerByteCount = Self.digestInfoPrefix.count + Self.syntheticDigest.count
    let paddingByteCount = profile.rawSignatureLength - trailerByteCount - 3
    var bytes: [UInt8] = [0, 1]
    bytes.append(contentsOf: repeatElement(0xFF, count: paddingByteCount))
    bytes.append(0)
    bytes.append(contentsOf: Self.digestInfoPrefix)
    bytes.append(contentsOf: Self.syntheticDigest)
    return Data(bytes)
  }

  @Test(arguments: [CardKeyProfile.rsa2048, .rsa3072])
  internal func acceptsExactSyntheticSha256Block(
    _ profile: CardKeyProfile
  ) throws {
    let decoded = try #require(
      RsaPkcs1Sha256EncodedMessage(
        encoded: Self.validBlock(profile),
        profile: profile
      )
    )
    #expect(decoded.digest == Self.syntheticDigest)
  }

  @Test
  internal func refusesAnotherRsaModulusWidth() {
    let rsa2048 = Self.validBlock(.rsa2048)
    let rsa3072 = Self.validBlock(.rsa3072)

    #expect(
      RsaPkcs1Sha256EncodedMessage(encoded: rsa3072, profile: .rsa2048)
        == nil
    )
    #expect(
      RsaPkcs1Sha256EncodedMessage(encoded: rsa2048, profile: .rsa3072)
        == nil
    )
  }

  @Test
  internal func refusesNonRsaProfile() {
    #expect(
      RsaPkcs1Sha256EncodedMessage(
        encoded: Self.validBlock(.rsa2048),
        profile: .ecdsaP384
      ) == nil
    )
  }

  @Test
  internal func refusesWrongWidth() {
    var block = Self.validBlock(.rsa3072)
    block.removeLast()
    #expect(
      RsaPkcs1Sha256EncodedMessage(encoded: block, profile: .rsa3072)
        == nil
    )
  }

  @Test
  internal func refusesNonFfPadding() {
    var block = Self.validBlock(.rsa3072)
    block[2] = 0
    #expect(
      RsaPkcs1Sha256EncodedMessage(encoded: block, profile: .rsa3072)
        == nil
    )
  }

  @Test
  internal func refusesAnotherDigestInfoAlgorithm() {
    var block = Self.validBlock(.rsa3072)
    let digestInfoOffset =
      block.count - Self.digestInfoPrefix.count - Self.syntheticDigest.count
    block[digestInfoOffset] ^= 1
    #expect(
      RsaPkcs1Sha256EncodedMessage(encoded: block, profile: .rsa3072)
        == nil
    )
  }
}
