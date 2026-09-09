// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// The supported FINEID card-key profiles, resolved from a certificate's
/// public key by Security.framework.
///
/// Both the app and the token extension use the same profile. Selecting from
/// the certificate, rather than the card generation, also fails closed if a
/// later card carries an unexpected key.
public enum CardKeyProfile: Equatable, Sendable {
  /// ECDSA P-256, the curve of the second signature certificate on
  /// cards that carry one.
  case ecdsaP256

  /// ECDSA P-384.
  case ecdsaP384

  /// RSA 2048-bit, used by the FINEID S4-1 v3.1 cards.
  case rsa2048

  /// RSA 3072-bit.
  case rsa3072

  /// RSA modulus sizes for the supported RSA profiles.
  private static let rsa2048KeySizeInBits = 2_048
  private static let rsa3072KeySizeInBits = 3_072

  /// EC field sizes for the supported ECC profiles.
  private static let ecdsaP256KeySizeInBits = 256
  private static let ecdsaP384KeySizeInBits = 384

  /// Raw P-256 signature length: `r || s`, two 32-byte field elements.
  private static let ecdsaP256SignatureBytes = 64

  /// Raw P-384 signature length: `r || s`, two 48-byte field elements.
  private static let ecdsaP384SignatureBytes = 96

  /// Raw RSA-2048 signature length: one modulus-wide block.
  private static let rsa2048SignatureBytes = 256

  /// Raw RSA-3072 signature length: one modulus-wide block.
  private static let rsa3072SignatureBytes = 384

  /// The Security key type constant for this profile.
  public var keyType: String {
    switch self {
    case .rsa2048, .rsa3072:
      kSecAttrKeyTypeRSA as String

    case .ecdsaP256, .ecdsaP384:
      kSecAttrKeyTypeECSECPrimeRandom as String
    }
  }

  /// The key size in bits.
  public var keySizeInBits: Int {
    switch self {
    case .rsa2048:
      Self.rsa2048KeySizeInBits

    case .rsa3072:
      Self.rsa3072KeySizeInBits

    case .ecdsaP256:
      Self.ecdsaP256KeySizeInBits

    case .ecdsaP384:
      Self.ecdsaP384KeySizeInBits
    }
  }

  /// The exact byte length of the card's raw signature.
  public var rawSignatureLength: Int {
    switch self {
    case .rsa2048:
      Self.rsa2048SignatureBytes

    case .rsa3072:
      Self.rsa3072SignatureBytes

    case .ecdsaP256:
      Self.ecdsaP256SignatureBytes

    case .ecdsaP384:
      Self.ecdsaP384SignatureBytes
    }
  }

  /// The expected length sent with PSO:CDS when it fits a short APDU.
  ///
  /// P-384 and RSA-2048 use their exact short-response lengths. RSA-3072
  /// is 384 bytes, so it requests the short maximum and lets the transport
  /// join continuation responses inside the same operation.
  public var expectedSignatureLength: ExpectedResponseLength? {
    switch self {
    case .ecdsaP256:
      ExpectedResponseLength(count: Self.ecdsaP256SignatureBytes)

    case .ecdsaP384:
      ExpectedResponseLength(count: Self.ecdsaP384SignatureBytes)

    case .rsa2048:
      ExpectedResponseLength(count: Self.rsa2048SignatureBytes)

    case .rsa3072:
      nil
    }
  }

  /// Resolves the profile from a leaf certificate's public key facts.
  public static func resolve(fromCertificate certificate: SecCertificate) -> Self? {
    guard let key = SecCertificateCopyKey(certificate) else { return nil }
    return Self.resolve(fromPublicKey: key)
  }

  /// Resolves the profile from a public or private Security key.
  public static func resolve(fromPublicKey key: SecKey) -> Self? {
    guard
      let attributes = SecKeyCopyAttributes(key) as? [CFString: Any],
      let certificateKeyType = attributes[kSecAttrKeyType] as? String,
      let keySize = attributes[kSecAttrKeySizeInBits] as? Int
    else {
      return nil
    }
    return [Self.ecdsaP256, .ecdsaP384, .rsa2048, .rsa3072].first { profile in
      profile.keyType == certificateKeyType && profile.keySizeInBits == keySize
    }
  }
}
