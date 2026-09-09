// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Known-answer vectors for AES-CMAC, plus a CBC round trip.
///
/// The AES-128 tags are RFC 4493 section 4 examples 1 to 4; the AES-256 tags
/// are NIST SP 800-38B appendix D.3 examples 13 to 16. Both suites mac the
/// same four message prefixes, which is why one message and one length list
/// drive them.
@Suite
internal struct AesCmacTests {
  /// RFC 4493 section 4 key, also NIST SP 800-38B appendix D.1.
  private static let aes128Key = WireHex.data("2b7e151628aed2a6abf7158809cf4f3c")

  /// NIST SP 800-38B appendix D.3 key.
  private static let aes256Key = WireHex.data(
    "603deb1015ca71be2b73aef0857d7781"
      + "1f352c073b6108d72d9810a30914dff4"
  )

  /// The four-block published message; each vector macs a prefix of it.
  private static let message = WireHex.data(
    "6bc1bee22e409f96e93d7e117393172a"
      + "ae2d8a571e03ac9c9eb76fac45af8e51"
      + "30c81c46a35ce411e5fbc1191a0a52ef"
      + "f69f2445df4f9b17ad2b417be66c3710"
  )

  /// The message lengths in bytes the published examples use: empty, one
  /// block, a partial block, and four whole blocks.
  private static let vectorLengths = [0, 16, 40, 64]

  /// An arbitrary but fixed initialization vector for the CBC round trip.
  private static let roundTripVector = WireHex.data("000102030405060708090a0b0c0d0e0f")

  /// A length that is not a whole number of blocks.
  private static let unalignedLength = 5

  @Test
  internal func matchesRfc4493Aes128Vectors() throws {
    let expected = [
      "bb1d6929e95937287fa37d129b756746",
      "070a16b46b4d4144f79bdd9dd04a287c",
      "dfa66747de9ae63030ca32611497c827",
      "51f0bebf7e3b9d92fc49741779363cfe",
    ]
    for (length, tagHex) in zip(Self.vectorLengths, expected) {
      let tag = try AesCmac.tag(
        key: Self.aes128Key,
        message: Data(Self.message.prefix(length))
      )
      #expect(tag == WireHex.data(tagHex), "AES-128 CMAC of \(length) bytes")
      #expect(tag.count == AesCmac.tagLength)
    }
  }

  @Test
  internal func matchesSp80038bAes256Vectors() throws {
    let expected = [
      "028962f61b7bf89efc6b551f4667d983",
      "28a7023f452e8f82bd4bf28d8c37c35c",
      "aaf3d8f1de5640c232f5b169b9c911e6",
      "e1992190549f6ed5696a2c056c315410",
    ]
    for (length, tagHex) in zip(Self.vectorLengths, expected) {
      let tag = try AesCmac.tag(
        key: Self.aes256Key,
        message: Data(Self.message.prefix(length))
      )
      #expect(tag == WireHex.data(tagHex), "AES-256 CMAC of \(length) bytes")
    }
  }

  @Test
  internal func macsASlicedMessageLikeAStandaloneOne() throws {
    // A Data slice does not start at index zero; the MAC must not index
    // into the buffer as though it did.
    let slice = Self.message.dropFirst(AesCbc.blockSize)
    let sliced = try AesCmac.tag(key: Self.aes256Key, message: slice)
    let standalone = try AesCmac.tag(key: Self.aes256Key, message: Data(slice))
    #expect(sliced == standalone)
  }

  @Test
  internal func secureMessagingTagIsThePrefixOfTheFullTag() throws {
    let full = try AesCmac.tag(key: Self.aes256Key, message: Self.message)
    let truncated = try AesCmac.secureMessagingTag(
      key: Self.aes256Key,
      message: Self.message
    )
    #expect(truncated.count == AesCmac.secureMessagingTagLength)
    #expect(truncated == full.prefix(AesCmac.secureMessagingTagLength))
  }

  @Test
  internal func rejectsAKeyThatIsNotAnAesKeyLength() throws {
    #expect(throws: AesCbc.Failure.keyLength) {
      try AesCmac.tag(key: Data(Self.aes128Key.dropLast()), message: Self.message)
    }
  }

  @Test
  internal func cbcRoundTripsABlockAlignedBuffer() throws {
    let ciphertext = try AesCbc.encrypt(
      key: Self.aes256Key,
      initializationVector: Self.roundTripVector,
      plaintext: Self.message
    )
    #expect(ciphertext.count == Self.message.count)
    #expect(ciphertext != Self.message)

    let recovered = try AesCbc.decrypt(
      key: Self.aes256Key,
      initializationVector: Self.roundTripVector,
      ciphertext: ciphertext
    )
    #expect(recovered == Self.message)
  }

  @Test
  internal func cbcChainsSoAChangedVectorChangesTheCiphertext() throws {
    let plaintext = Data(Self.message.prefix(AesCbc.blockSize))
    let underZeroVector = try AesCbc.encrypt(
      key: Self.aes256Key,
      initializationVector: Data(repeating: 0, count: AesCbc.blockSize),
      plaintext: plaintext
    )
    let underFixedVector = try AesCbc.encrypt(
      key: Self.aes256Key,
      initializationVector: Self.roundTripVector,
      plaintext: plaintext
    )
    #expect(underZeroVector != underFixedVector)
  }

  @Test
  internal func cbcRefusesAnUnalignedBuffer() throws {
    #expect(throws: AesCbc.Failure.blockAlignment) {
      try AesCbc.encrypt(
        key: Self.aes256Key,
        initializationVector: Self.roundTripVector,
        plaintext: Data(Self.message.prefix(Self.unalignedLength))
      )
    }
  }

  @Test
  internal func cbcRefusesAShortInitializationVector() throws {
    #expect(throws: AesCbc.Failure.initializationVectorLength) {
      try AesCbc.encrypt(
        key: Self.aes256Key,
        initializationVector: Data(Self.roundTripVector.dropLast()),
        plaintext: Data(Self.message.prefix(AesCbc.blockSize))
      )
    }
  }

  @Test
  internal func ecbBlockPrimitiveRefusesAnythingButOneBlock() throws {
    #expect(throws: AesCbc.Failure.blockLength) {
      try AesCbc.encryptBlock(
        key: Self.aes256Key,
        block: Data(Self.message.prefix(Self.unalignedLength))
      )
    }
  }
}
