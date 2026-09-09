// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoTokenKit
import Foundation
import Security

/// Maps a live CryptoTokenKit algorithm chain to the pure CardCore resolver.
@_spi(TokenExtension)
public enum SigningAlgorithmResolver {
  /// Known candidates used only to make the live CTK request legible.
  private static let knownAlgorithms: [(String, SecKeyAlgorithm)] = [
    ("ecdsaDigestSHA224", .ecdsaSignatureDigestX962SHA224),
    ("ecdsaDigestSHA256", .ecdsaSignatureDigestX962SHA256),
    ("ecdsaMessageSHA256", .ecdsaSignatureMessageX962SHA256),
    ("ecdsaDigestSHA384", .ecdsaSignatureDigestX962SHA384),
    ("ecdsaMessageSHA384", .ecdsaSignatureMessageX962SHA384),
    ("ecdsaDigestSHA512", .ecdsaSignatureDigestX962SHA512),
    ("ecdsaMessageSHA512", .ecdsaSignatureMessageX962SHA512),
    ("rsaRaw", .rsaSignatureRaw),
    ("rsaDigPKCS1SHA1", .rsaSignatureDigestPKCS1v15SHA1),
    ("rsaMsgPKCS1SHA1", .rsaSignatureMessagePKCS1v15SHA1),
    ("rsaDigestPSSSHA256", .rsaSignatureDigestPSSSHA256),
    ("rsaMessagePSSSHA256", .rsaSignatureMessagePSSSHA256),
    ("rsaDigestPKCS1SHA256", .rsaSignatureDigestPKCS1v15SHA256),
    ("rsaMessagePKCS1SHA256", .rsaSignatureMessagePKCS1v15SHA256),
    ("rsaDigestPKCS1SHA384", .rsaSignatureDigestPKCS1v15SHA384),
    ("rsaMessagePKCS1SHA384", .rsaSignatureMessagePKCS1v15SHA384),
    ("rsaDigestPKCS1SHA512", .rsaSignatureDigestPKCS1v15SHA512),
    ("rsaMessagePKCS1SHA512", .rsaSignatureMessagePKCS1v15SHA512),
    ("ecdsaDigestRFC4754SHA384", .ecdsaSignatureDigestRFC4754SHA384),
  ]

  /// Whether the token should advertise this live CTK algorithm.
  public static func advertises(
    _ algorithm: TKTokenKeyAlgorithm,
    profile: CardKeyProfile
  ) -> Bool {
    selectedAlgorithm(algorithm, profile: profile) != nil
  }

  /// Names target and associated-chain matches for device traces.
  public static func describe(_ algorithm: TKTokenKeyAlgorithm) -> String {
    let targets = Self.knownAlgorithms
      .filter { candidate in
        algorithm.isAlgorithm(candidate.1)
      }
      .map(\.0)
    let chain = Self.knownAlgorithms
      .filter { candidate in
        algorithm.supportsAlgorithm(candidate.1)
      }
      .map(\.0)
    let targetLabel = targets.isEmpty ? "none-of-known" : targets.joined(separator: ",")
    let chainLabel = chain.isEmpty ? "none-of-known" : chain.joined(separator: ",")
    return "target=\(targetLabel); chain=\(chainLabel)"
  }

  /// Whether this certificate profile can publish a sign-capable key.
  public static func supportsSigning(_ profile: CardKeyProfile) -> Bool {
    !CardSignRequestResolver.exactAlgorithms(for: profile).isEmpty
  }

  /// Resolves one live CTK request, including Apple's raw-RSA adapter.
  public static func resolve(
    _ algorithm: TKTokenKeyAlgorithm,
    input: Data,
    profile: CardKeyProfile
  ) -> SignRequest? {
    guard
      let selected = selectedAlgorithm(algorithm, profile: profile)
    else {
      return nil
    }
    return CardSignRequestResolver.resolve(
      algorithm: selected,
      input: input,
      profile: profile
    )
  }

  /// Selects one testable Security.framework shape from a live CTK chain.
  private static func selectedAlgorithm(
    _ algorithm: TKTokenKeyAlgorithm,
    profile: CardKeyProfile
  ) -> SecKeyAlgorithm? {
    if let exact = CardSignRequestResolver.exactAlgorithms(for: profile)
      .first(where: { algorithm.isAlgorithm($0) })
    {
      return exact
    }
    guard
      Self.isRsa(profile),
      isRawRsaPkcs1Request(algorithm)
    else {
      return nil
    }
    return .rsaSignatureRaw
  }

  /// Apple's raw target plus a PKCS#1/SHA-256 associated chain.
  private static func isRawRsaPkcs1Request(_ algorithm: TKTokenKeyAlgorithm) -> Bool {
    algorithm.isAlgorithm(.rsaSignatureRaw)
      && algorithm.supportsAlgorithm(.rsaSignatureDigestPKCS1v15SHA256)
  }

  /// Whether the selected certificate carries a supported RSA modulus.
  private static func isRsa(_ profile: CardKeyProfile) -> Bool {
    switch profile {
    case .ecdsaP256, .ecdsaP384:
      false

    case .rsa2048, .rsa3072:
      true
    }
  }
}
