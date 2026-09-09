// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// The qualified document-signing shape for each supported card key.
extension CardKeyProfile {
  /// An EC signature carries two coordinates, so each is half the
  /// raw `r || s` signature of the curve in hand.
  private static let ecdsaCoordinateCount = 2

  /// The exact card request for a SHA-384 digest of CMS signed attributes.
  internal func qualifiedDocumentRequest(digest: Data) -> SignRequest? {
    let scheme: SigningScheme
    switch self {
    case .ecdsaP256, .ecdsaP384:
      scheme = .ecdsa

    case .rsa2048, .rsa3072:
      scheme = .rsaPkcs1
    }
    return SignRequest.resolve(
      profile: self,
      algorithm: SigningAlgorithm(hash: .sha384, scheme: scheme),
      digest: digest
    )
  }

  /// The signature in the form an XML signature carries.
  ///
  /// ECDSA is the raw `r || s` coordinate pair, each padded to the
  /// field size (RFC 4051 §2.3), re-encoded from the X9.62 DER the
  /// qualified product verifies with; RSA is the modulus-wide block
  /// both forms share. Nil when a DER signature does not describe
  /// two coordinates of this key's curve.
  internal func xmlSignature(fromWire signature: Data) -> Data? {
    switch self {
    case .ecdsaP256, .ecdsaP384:
      EcdsaSignature.rawConcatenation(
        fromDer: signature,
        coordinateOctets: rawSignatureLength / Self.ecdsaCoordinateCount
      )

    case .rsa2048, .rsa3072:
      signature
    }
  }
}
