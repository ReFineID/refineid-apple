// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Cryptographic signature verification over XAdES SignedInfo elements.
extension AsicVerification {
  internal static func verifyCryptographicSignature(
    parsed: ParsedSignature,
    publicKey: SecKey
  ) -> Bool {
    guard let signatureValueBytes = parsed.signatureValueBytes,
      let signatureMethod = parsed.signatureMethod,
      let secAlgorithm = resolveSecKeyAlgorithm(method: signatureMethod),
      let hashAlgorithmName = resolveHashAlgorithmName(method: signatureMethod)
    else {
      return false
    }

    let wireSignature: Data
    if signatureMethod.contains("ecdsa") {
      wireSignature =
        EcdsaSignature.derFromRawConcatenation(signatureValueBytes) ?? signatureValueBytes
    } else {
      wireSignature = signatureValueBytes
    }

    if let signedInfoRaw = parsed.signedInfoRawXml,
      verifySignedBytes(
        bytes: Data(signedInfoRaw.utf8),
        hashAlgorithm: hashAlgorithmName,
        publicKey: publicKey,
        algorithm: secAlgorithm,
        signature: wireSignature
      )
    {
      return true
    }

    if let canonical = canonicalizeSignedInfo(parsed: parsed),
      verifySignedBytes(
        bytes: Data(canonical.utf8),
        hashAlgorithm: hashAlgorithmName,
        publicKey: publicKey,
        algorithm: secAlgorithm,
        signature: wireSignature
      )
    {
      return true
    }

    return false
  }

  private static func verifySignedBytes(
    bytes: Data,
    hashAlgorithm: String,
    publicKey: SecKey,
    algorithm: SecKeyAlgorithm,
    signature: Data
  ) -> Bool {
    guard let digestBytes = digest(of: bytes, algorithm: hashAlgorithm) else {
      return false
    }
    var error: Unmanaged<CFError>?
    return SecKeyVerifySignature(
      publicKey,
      algorithm,
      digestBytes as CFData,
      signature as CFData,
      &error
    )
  }
}
