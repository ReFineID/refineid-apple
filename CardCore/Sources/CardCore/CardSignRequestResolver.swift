// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Security

/// Resolves one Security.framework signing shape to an on-card request.
///
/// CryptoTokenKit's `TKTokenKeyAlgorithm` is system-created and cannot be
/// constructed in a unit test. The token extension therefore keeps only the
/// live target/associated-chain match in its process and hands the selected
/// `SecKeyAlgorithm` to this pure, directly testable resolver.
@_spi(TokenExtension)
public enum CardSignRequestResolver {
  /// One exact digest or message shape the card can reproduce.
  private struct Shape {
    let secKeyAlgorithm: SecKeyAlgorithm
    let hash: SigningHash
    let scheme: SigningScheme
    let hashesMessage: Bool
  }

  /// ECDSA shapes supported by the P-384 authentication key.
  private static let ecdsaShapes: [Shape] = [
    Shape(
      secKeyAlgorithm: .ecdsaSignatureDigestX962SHA256,
      hash: .sha256,
      scheme: .ecdsa,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureMessageX962SHA256,
      hash: .sha256,
      scheme: .ecdsa,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureDigestX962SHA384,
      hash: .sha384,
      scheme: .ecdsa,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureMessageX962SHA384,
      hash: .sha384,
      scheme: .ecdsa,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureDigestX962SHA512,
      hash: .sha512,
      scheme: .ecdsa,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureMessageX962SHA512,
      hash: .sha512,
      scheme: .ecdsa,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .ecdsaSignatureDigestX962SHA224,
      hash: .sha224,
      scheme: .ecdsa,
      hashesMessage: false),
  ]

  /// The raw-signature shape, offered only where Security defines it.
  ///
  /// It names the same P-384 digest signature as the X9.62 shape above and
  /// differs only in how the caller wants the two integers packed, so a
  /// system without the constant loses a packing, never the ability to
  /// authenticate.
  private static let rawEcdsaShapes: [Shape] = [
    Shape(
      secKeyAlgorithm: .ecdsaSignatureDigestRFC4754SHA384,
      hash: .sha384,
      scheme: .ecdsa,
      hashesMessage: false)
  ]

  /// RSA client-authentication and qualified-signature shapes.
  private static let rsaShapes: [Shape] = [
    Shape(
      secKeyAlgorithm: .rsaSignatureDigestPKCS1v15SHA1,
      hash: .sha1,
      scheme: .rsaPkcs1,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .rsaSignatureMessagePKCS1v15SHA1,
      hash: .sha1,
      scheme: .rsaPkcs1,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .rsaSignatureDigestPSSSHA256,
      hash: .sha256,
      scheme: .rsaPss,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .rsaSignatureMessagePSSSHA256,
      hash: .sha256,
      scheme: .rsaPss,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .rsaSignatureDigestPKCS1v15SHA256,
      hash: .sha256,
      scheme: .rsaPkcs1,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .rsaSignatureMessagePKCS1v15SHA256,
      hash: .sha256,
      scheme: .rsaPkcs1,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .rsaSignatureDigestPKCS1v15SHA384,
      hash: .sha384,
      scheme: .rsaPkcs1,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .rsaSignatureMessagePKCS1v15SHA384,
      hash: .sha384,
      scheme: .rsaPkcs1,
      hashesMessage: true),
    Shape(
      secKeyAlgorithm: .rsaSignatureDigestPKCS1v15SHA512,
      hash: .sha512,
      scheme: .rsaPkcs1,
      hashesMessage: false),
    Shape(
      secKeyAlgorithm: .rsaSignatureMessagePKCS1v15SHA512,
      hash: .sha512,
      scheme: .rsaPkcs1,
      hashesMessage: true),
  ]

  /// Exact Security.framework targets supported by one certificate profile.
  ///
  /// Raw RSA is deliberately absent: the live CryptoTokenKit shim admits it
  /// only when PKCS#1/SHA-256 also occurs in the associated algorithm chain.
  public static func exactAlgorithms(
    for profile: CardKeyProfile
  ) -> [SecKeyAlgorithm] {
    shapes(for: profile).map(\.secKeyAlgorithm)
  }

  /// Normalizes a selected Security.framework shape to one card request.
  ///
  /// Digest variants must carry exactly one digest. Message variants are
  /// hashed exactly once. Raw RSA is accepted only as a complete,
  /// profile-width EMSA-PKCS1-v1_5 SHA-256 block.
  public static func resolve(
    algorithm: SecKeyAlgorithm,
    input: Data,
    profile: CardKeyProfile
  ) -> SignRequest? {
    if let shape = shapes(for: profile).first(where: { shape in
      shape.secKeyAlgorithm == algorithm
    }) {
      let digest: Data
      if shape.hashesMessage {
        digest = hash(input, with: shape.hash)
      } else {
        guard input.count == shape.hash.digestByteCount else { return nil }
        digest = input
      }
      return SignRequest.resolve(
        profile: profile,
        algorithm: SigningAlgorithm(hash: shape.hash, scheme: shape.scheme),
        digest: digest
      )
    }

    guard
      algorithm == .rsaSignatureRaw,
      let digest = RsaPkcs1Sha256EncodedMessage(
        encoded: input,
        profile: profile
      )?.digest
    else {
      return nil
    }
    return SignRequest.resolve(
      profile: profile,
      algorithm: SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1),
      digest: digest
    )
  }

  /// Shapes behind one concrete certificate profile.
  private static func shapes(for profile: CardKeyProfile) -> [Shape] {
    switch profile {
    case .ecdsaP256, .ecdsaP384:
      Self.ecdsaShapes + Self.rawEcdsaShapes

    case .rsa2048, .rsa3072:
      Self.rsaShapes
    }
  }

  /// Hashes one message according to the selected exact shape.
  private static func hash(_ input: Data, with hash: SigningHash) -> Data {
    switch hash {
    case .sha1:
      Data(Insecure.SHA1.hash(data: input))

    case .sha224:
      // No SHA-224 message form is advertised.
      input

    case .sha256:
      Data(SHA256.hash(data: input))

    case .sha384:
      Data(SHA384.hash(data: input))

    case .sha512:
      Data(SHA512.hash(data: input))
    }
  }
}
