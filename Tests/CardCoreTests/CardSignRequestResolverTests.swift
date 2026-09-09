// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// swiftlint:disable:next attributes
@_spi(TokenExtension) import CardCore
import CryptoKit
import Foundation
import Security
import Testing

/// Direct tests for the pure resolver behind the live CryptoTokenKit shim.
@Suite
internal struct CardSignRequestResolverTests {
  /// A recognizable synthetic SHA-256 digest.
  private static let digest = Data((0..<32).map(UInt8.init))

  /// A message whose digest is computed by message-form algorithms.
  private static let message = Data("RSA-2048 token request".utf8)

  /// Fixed EMSA-PKCS1-v1_5 SHA-256 DigestInfo prefix.
  private static let digestInfoPrefix: [UInt8] = [
    0x30, 0x31, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
    0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20,
  ]

  /// Builds one complete modulus-wide PKCS#1/SHA-256 encoded message.
  private static func rawBlock(for profile: CardKeyProfile) -> Data {
    let trailerCount = Self.digestInfoPrefix.count + Self.digest.count
    let paddingCount = profile.rawSignatureLength - trailerCount - 3
    var bytes: [UInt8] = [0, 1]
    bytes.append(contentsOf: repeatElement(0xFF, count: paddingCount))
    bytes.append(0)
    bytes.append(contentsOf: Self.digestInfoPrefix)
    bytes.append(contentsOf: Self.digest)
    return Data(bytes)
  }

  /// RSA publishes every native shape the card can make: PSS and
  /// PKCS#1 over SHA-256, and PKCS#1 over the two longer digests.
  ///
  /// Order is part of the contract. A consumer offered several shapes
  /// takes the first it supports, so the strongest available scheme
  /// must come before the weaker one for the same digest.
  @Test
  internal func rsa2048ExactAlgorithmsAreComplete() {
    #expect(
      CardSignRequestResolver.exactAlgorithms(for: .rsa2048) == [
        .rsaSignatureDigestPKCS1v15SHA1,
        .rsaSignatureMessagePKCS1v15SHA1,
        .rsaSignatureDigestPSSSHA256,
        .rsaSignatureMessagePSSSHA256,
        .rsaSignatureDigestPKCS1v15SHA256,
        .rsaSignatureMessagePKCS1v15SHA256,
        .rsaSignatureDigestPKCS1v15SHA384,
        .rsaSignatureMessagePKCS1v15SHA384,
        .rsaSignatureDigestPKCS1v15SHA512,
        .rsaSignatureMessagePKCS1v15SHA512,
      ]
    )
  }

  /// PKCS#1 digest form passes one exact digest through unchanged.
  @Test
  internal func rsa2048Pkcs1DigestResolves() throws {
    let request = try #require(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureDigestPKCS1v15SHA256,
        input: Self.digest,
        profile: .rsa2048
      )
    )

    #expect(
      request.algorithm
        == SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1)
    )
    #expect(request.digest == Self.digest)
    #expect(request.expectedSignatureLength?.count == 256)
    #expect(request.rawSignatureLength == 256)
  }

  /// PKCS#1 message form hashes its input exactly once.
  @Test
  internal func rsa2048Pkcs1MessageResolves() throws {
    let request = try #require(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureMessagePKCS1v15SHA256,
        input: Self.message,
        profile: .rsa2048
      )
    )

    #expect(
      request.algorithm
        == SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1)
    )
    #expect(request.digest == Data(SHA256.hash(data: Self.message)))
  }

  /// PSS digest form passes one exact digest through unchanged.
  @Test
  internal func rsa2048PssDigestResolves() throws {
    let request = try #require(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureDigestPSSSHA256,
        input: Self.digest,
        profile: .rsa2048
      )
    )

    #expect(
      request.algorithm
        == SigningAlgorithm(hash: .sha256, scheme: .rsaPss)
    )
    #expect(request.digest == Self.digest)
  }

  /// PSS message form hashes its input exactly once.
  @Test
  internal func rsa2048PssMessageResolves() throws {
    let request = try #require(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureMessagePSSSHA256,
        input: Self.message,
        profile: .rsa2048
      )
    )

    #expect(
      request.algorithm
        == SigningAlgorithm(hash: .sha256, scheme: .rsaPss)
    )
    #expect(request.digest == Data(SHA256.hash(data: Self.message)))
  }

  /// Raw CTK form accepts the exact 256-byte encoded message only.
  @Test
  internal func rsa2048RawPkcs1Resolves() throws {
    let request = try #require(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureRaw,
        input: Self.rawBlock(for: .rsa2048),
        profile: .rsa2048
      )
    )

    #expect(
      request.algorithm
        == SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1)
    )
    #expect(request.digest == Self.digest)
    #expect(request.expectedSignatureLength?.count == 256)
  }

  /// A raw request cannot cross modulus widths or arrive truncated.
  @Test
  internal func rsa2048RawPkcs1RefusesWrongWidths() {
    var truncated = Self.rawBlock(for: .rsa2048)
    truncated.removeLast()

    #expect(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureRaw,
        input: truncated,
        profile: .rsa2048
      ) == nil
    )
    #expect(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureRaw,
        input: Self.rawBlock(for: .rsa3072),
        profile: .rsa2048
      ) == nil
    )
  }

  /// Digest-form requests cannot accidentally hash arbitrary input.
  @Test
  internal func rsa2048DigestShapesRefuseWrongLength() {
    #expect(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureDigestPKCS1v15SHA256,
        input: Data(repeating: 0xA5, count: 31),
        profile: .rsa2048
      ) == nil
    )
    #expect(
      CardSignRequestResolver.resolve(
        algorithm: .rsaSignatureDigestPSSSHA256,
        input: Data(repeating: 0xA5, count: 33),
        profile: .rsa2048
      ) == nil
    )
  }
}
