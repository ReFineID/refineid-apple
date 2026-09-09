// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension CertificateRevocationList {
  /// Signature, issuer, and validity sequences precede subject in a certificate.
  private static let sequencesBeforeCertificateSubject = 3

  /// Parses a certificate's Security handle, serial, and exact subject Name.
  internal static func certificateContext(
    from encoded: Data
  ) throws -> CertificateContext {
    guard let certificate = SecCertificateCreateWithData(nil, encoded as CFData) else {
      throw ValidationFailure.certificateUnparseable
    }
    do {
      let tbs = try Self.certificateTbs(in: encoded)
      let identity = try Self.certificateIdentity(in: encoded, tbs: tbs)
      return CertificateContext(
        certificate: certificate,
        serialNumber: identity.serialNumber,
        subjectName: identity.subjectName,
        canSignCrl: try Self.certificateAllowsCrlSigning(
          in: encoded,
          tbs: tbs
        )
      )
    } catch {
      throw ValidationFailure.certificateUnparseable
    }
  }

  /// Extracts the one exact TBSCertificate from a Certificate.
  private static func certificateTbs(
    in encoded: Data
  ) throws -> DerReader.Element {
    let outer = try Self.onlyElement(in: encoded, tag: DerValues.tagSequence)
    var certificateReader = DerReader(encoded, within: outer)
    let tbs = try Self.requiredElement(
      from: &certificateReader,
      in: encoded,
      tag: DerValues.tagSequence
    )
    _ = try Self.requiredElement(
      from: &certificateReader,
      in: encoded,
      tag: DerValues.tagSequence
    )
    _ = try Self.requiredElement(
      from: &certificateReader,
      in: encoded,
      tag: DerValues.tagBitString
    )
    guard certificateReader.isAtEnd else { throw ValidationFailure.malformed }
    return tbs
  }

  /// Extracts the serial magnitude and exact subject Name from TBSCertificate.
  private static func certificateIdentity(
    in encoded: Data,
    tbs: DerReader.Element
  ) throws -> (serialNumber: Data, subjectName: Data) {
    var reader = DerReader(encoded, within: tbs)
    var serial = try Self.requiredElement(from: &reader, in: encoded)
    if serial.tag == DerValues.tagContext0Constructed {
      serial = try Self.requiredElement(
        from: &reader,
        in: encoded,
        tag: DerValues.tagInteger
      )
    }
    guard serial.tag == DerValues.tagInteger else {
      throw ValidationFailure.malformed
    }
    let serialNumber = try Self.unsignedIntegerContent(
      reader.contentData(of: serial)
    )
    for _ in 0..<Self.sequencesBeforeCertificateSubject {
      _ = try Self.requiredElement(
        from: &reader,
        in: encoded,
        tag: DerValues.tagSequence
      )
    }
    let subject = try Self.requiredElement(
      from: &reader,
      in: encoded,
      tag: DerValues.tagSequence
    )
    _ = try Self.requiredElement(
      from: &reader,
      in: encoded,
      tag: DerValues.tagSequence
    )
    return (serialNumber, reader.data(of: subject))
  }

  /// Maps a verified AlgorithmIdentifier to Security's signature verifier.
  internal static func signatureAlgorithm(
    from encoded: Data
  ) throws -> SecKeyAlgorithm {
    let sequence = try Self.onlyElement(in: encoded, tag: DerValues.tagSequence)
    var reader = DerReader(encoded, within: sequence)
    let oid = try Self.requiredElement(
      from: &reader,
      in: encoded,
      tag: DerValues.tagObjectIdentifier
    )
    let identifier = reader.data(of: oid)
    let parameters = try Self.nextElement(from: &reader, in: encoded)
    guard reader.isAtEnd else {
      throw ValidationFailure.unsupportedSignatureAlgorithm
    }
    if let algorithm = Self.ecdsaAlgorithm(identifier) {
      guard parameters == nil else {
        throw ValidationFailure.unsupportedSignatureAlgorithm
      }
      return algorithm
    }
    guard let algorithm = Self.rsaAlgorithm(identifier) else {
      throw ValidationFailure.unsupportedSignatureAlgorithm
    }
    try Self.requireNullParameters(parameters)
    return algorithm
  }

  /// Maps one supported parameterless ECDSA identifier.
  private static func ecdsaAlgorithm(_ identifier: Data) -> SecKeyAlgorithm? {
    switch identifier {
    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256):
      .ecdsaSignatureMessageX962SHA256

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha384):
      .ecdsaSignatureMessageX962SHA384

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha512):
      .ecdsaSignatureMessageX962SHA512

    default:
      nil
    }
  }

  /// Maps one supported RSA PKCS#1 v1.5 identifier.
  private static func rsaAlgorithm(_ identifier: Data) -> SecKeyAlgorithm? {
    switch identifier {
    case DerEncoder.objectIdentifier(SignOids.sha256WithRsa):
      .rsaSignatureMessagePKCS1v15SHA256

    case DerEncoder.objectIdentifier(SignOids.sha384WithRsa):
      .rsaSignatureMessagePKCS1v15SHA384

    case DerEncoder.objectIdentifier(SignOids.sha512WithRsa):
      .rsaSignatureMessagePKCS1v15SHA512

    default:
      nil
    }
  }

  /// Requires the explicit NULL parameters used by RSA signature identifiers.
  private static func requireNullParameters(
    _ parameters: DerReader.Element?
  ) throws {
    guard
      let parameters,
      parameters.tag == DerValues.tagNull,
      parameters.content.isEmpty
    else {
      throw ValidationFailure.unsupportedSignatureAlgorithm
    }
  }

  /// Verifies the signature over the exact TBSCertList DER encoding.
  internal static func signatureIsValid(
    _ signature: Data,
    over data: Data,
    with certificate: SecCertificate,
    algorithm: SecKeyAlgorithm
  ) -> Bool {
    guard
      let key = SecCertificateCopyKey(certificate),
      SecKeyIsAlgorithmSupported(key, .verify, algorithm)
    else {
      return false
    }
    var error: Unmanaged<CFError>?
    let valid = SecKeyVerifySignature(
      key,
      algorithm,
      data as CFData,
      signature as CFData,
      &error
    )
    _ = error?.takeRetainedValue()
    return valid
  }

  /// The issuer Name normalized by Security for relationship checks.
  internal static func issuer(of certificate: SecCertificate) -> Data? {
    SecCertificateCopyNormalizedIssuerSequence(certificate) as Data?
  }

  /// The subject Name normalized by Security for relationship checks.
  internal static func subject(of certificate: SecCertificate) -> Data? {
    SecCertificateCopyNormalizedSubjectSequence(certificate) as Data?
  }
}
