// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation
import Security
import Testing

/// Certificate-key profile selection and shared signature normalization.
@Suite
internal struct CardKeyProfileTests {
  private enum FixtureError: Error {
    case keyCreation
  }

  /// Builds a transient test key; no key material is persisted.
  private static func key(type: CFString, bits: Int) throws -> SecKey {
    let attributes: [CFString: Any] = [
      kSecAttrKeyType: type,
      kSecAttrKeySizeInBits: bits,
    ]
    var error: Unmanaged<CFError>?
    guard
      let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error)
    else {
      _ = error?.takeRetainedValue()
      throw FixtureError.keyCreation
    }
    return key
  }

  @Test
  internal func resolvesSupportedCardKeyProfiles() throws {
    let p384 = try Self.key(type: kSecAttrKeyTypeECSECPrimeRandom, bits: 384)
    let rsa3072 = try Self.key(type: kSecAttrKeyTypeRSA, bits: 3_072)
    let rsa2048 = try Self.key(type: kSecAttrKeyTypeRSA, bits: 2_048)

    #expect(CardKeyProfile.resolve(fromPublicKey: p384) == .ecdsaP384)
    #expect(CardKeyProfile.resolve(fromPublicKey: rsa3072) == .rsa3072)
    #expect(CardKeyProfile.resolve(fromPublicKey: rsa2048) == .rsa2048)
    #expect(CardKeyProfile.ecdsaP384.rawSignatureLength == 96)
    #expect(CardKeyProfile.ecdsaP384.expectedSignatureLength?.count == 96)
    #expect(CardKeyProfile.rsa2048.rawSignatureLength == 256)
    #expect(CardKeyProfile.rsa2048.expectedSignatureLength?.count == 256)
    #expect(CardKeyProfile.rsa3072.rawSignatureLength == 384)
    #expect(CardKeyProfile.rsa3072.expectedSignatureLength == nil)
  }

  @Test(arguments: [CardKeyProfile.rsa2048, .rsa3072])
  internal func rsaRequestPreservesAndLocallyVerifiesTheCardResult(
    _ profile: CardKeyProfile
  ) throws {
    let privateKey = try Self.key(
      type: kSecAttrKeyTypeRSA,
      bits: profile.keySizeInBits
    )
    let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
    let digest = Data(SHA384.hash(data: Data("old-card-pdf".utf8)))
    var error: Unmanaged<CFError>?
    let signature = try #require(
      SecKeyCreateSignature(
        privateKey,
        .rsaSignatureDigestPKCS1v15SHA384,
        digest as CFData,
        &error
      ) as Data?
    )
    let request = try #require(
      SignRequest.resolve(
        profile: profile,
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        digest: digest
      )
    )

    #expect(request.wireSignature(from: signature) == signature)
    #expect(request.isSatisfied(by: signature, from: publicKey))
    var corrupted = signature
    corrupted[corrupted.startIndex] ^= 1
    #expect(!request.isSatisfied(by: corrupted, from: publicKey))
    #expect(request.wireSignature(from: Data(signature.dropLast())) == nil)
    let imprint = try QualifiedDocumentCms.signatureTimestampDigest(
      signatureValue: signature
    )
    #expect(imprint == Data(SHA384.hash(data: signature)))
    #expect(
      imprint
        != Data(SHA384.hash(data: DerEncoder.octetString(signature)))
    )
  }

  @Test
  internal func signatureTimestampHashesTheExactStoredValue() throws {
    let first = Data(repeating: 0x80, count: 48)
    let second = Data(repeating: 0x01, count: 48)
    let request = try #require(
      SignRequest.resolve(
        profile: .ecdsaP384,
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .ecdsa),
        digest: Data(repeating: 0xA5, count: 48)
      )
    )
    let raw = first + second
    let stored = try #require(request.wireSignature(from: raw))
    let imprint = try QualifiedDocumentCms.signatureTimestampDigest(
      signatureValue: stored
    )

    #expect(imprint == Data(SHA384.hash(data: stored)))
    #expect(imprint != Data(SHA384.hash(data: raw)))
    #expect(imprint != Data(SHA384.hash(data: DerEncoder.octetString(stored))))
  }

  @Test
  internal func rsa2048ResolvesTokenSigningSchemes() throws {
    let digest = Data(repeating: 0xA5, count: 32)
    let pkcs1 = try #require(
      SignRequest.resolve(
        profile: .rsa2048,
        algorithm: SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1),
        digest: digest
      )
    )
    let pss = try #require(
      SignRequest.resolve(
        profile: .rsa2048,
        algorithm: SigningAlgorithm(hash: .sha256, scheme: .rsaPss),
        digest: digest
      )
    )

    #expect(pkcs1.verifyAlgorithm == .rsaSignatureDigestPKCS1v15SHA256)
    #expect(pss.verifyAlgorithm == .rsaSignatureDigestPSSSHA256)
    #expect(pkcs1.expectedSignatureLength?.count == 256)
    #expect(pss.expectedSignatureLength?.count == 256)
  }

  @Test
  internal func contradictoryRequestsAreRefused() {
    #expect(
      SignRequest.resolve(
        profile: .ecdsaP384,
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        digest: Data(repeating: 0xA5, count: 48)
      ) == nil
    )
    #expect(
      SignRequest.resolve(
        profile: .rsa3072,
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        digest: Data(repeating: 0xA5, count: 32)
      ) == nil
    )
  }
}
