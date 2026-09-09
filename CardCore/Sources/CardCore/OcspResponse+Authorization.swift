// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension OcspResponse {
  /// Supported ECDSA signature OIDs and their Security algorithms.
  private static let ecdsaSignatureAlgorithms: [Data: SecKeyAlgorithm] = [
    DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256): .ecdsaSignatureMessageX962SHA256,
    DerEncoder.objectIdentifier(SignOids.ecdsaWithSha384): .ecdsaSignatureMessageX962SHA384,
    DerEncoder.objectIdentifier(SignOids.ecdsaWithSha512): .ecdsaSignatureMessageX962SHA512,
  ]

  /// Supported RSA signature OIDs and their Security algorithms.
  private static let rsaSignatureAlgorithms: [Data: SecKeyAlgorithm] = [
    DerEncoder.objectIdentifier(SignOids.sha256WithRsa): .rsaSignatureMessagePKCS1v15SHA256,
    DerEncoder.objectIdentifier(SignOids.sha384WithRsa): .rsaSignatureMessagePKCS1v15SHA384,
    DerEncoder.objectIdentifier(SignOids.sha512WithRsa): .rsaSignatureMessagePKCS1v15SHA512,
  ]

  /// Determines whether the named signer can issue this response for issuer.
  internal static func authorization(
    _ signer: ParsedCertificate,
    by issuer: ParsedCertificate,
    at producedAt: Date
  ) throws -> ResponderAuthorization {
    if signer.der == issuer.der {
      return .authorized
    }
    guard
      Self.issuer(of: signer.certificate) == Self.subject(of: issuer.certificate),
      try Self.hasOcspSigningExtendedKeyUsage(in: signer.der),
      try Self.delegatedResponderKeyUsagePermitsSigning(in: signer.der)
    else {
      return .unauthorized
    }
    guard
      CertificateIssuer.isDirectlyIssuedByPlatform(
        signer.der, by: issuer.der, at: producedAt
      )
    else {
      return .unauthorized
    }
    guard try Self.hasOcspNoCheckExtension(in: signer.der) else {
      return .revocationCheckRequired
    }
    return .authorized
  }

  /// Reads id-kp-OCSPSigning from a delegated responder certificate.
  private static func hasOcspSigningExtendedKeyUsage(in certificate: Data) throws -> Bool {
    let extensions = try Self.certificateExtensions(in: certificate)
    for extensionValue in extensions
    where extensionValue.oid
      == DerEncoder.objectIdentifier(SignOids.extendedKeyUsage)
    {
      let sequence = try Self.onlyElement(
        in: extensionValue.value,
        tag: DerValues.tagSequence
      )
      var usageReader = DerReader(extensionValue.value, within: sequence)
      var permitsOcspSigning = false
      while let purpose = usageReader.next() {
        guard purpose.tag == DerValues.tagObjectIdentifier else {
          throw ValidationFailure.malformed
        }
        if usageReader.data(of: purpose)
          == DerEncoder.objectIdentifier(SignOids.ocspSigning)
        {
          permitsOcspSigning = true
        }
      }
      guard usageReader.isAtEnd else { throw ValidationFailure.malformed }
      return permitsOcspSigning
    }
    return false
  }

  /// Applies RFC 5280 KeyUsage semantics to a delegated OCSP responder.
  ///
  /// KeyUsage is optional, but when the certificate carries it the
  /// digitalSignature bit must authorize the response signature. This check
  /// is explicit because raw `SecKeyVerifySignature` does not apply X.509
  /// usage restrictions and the basic path policy has no OCSP leaf purpose.
  internal static func delegatedResponderKeyUsagePermitsSigning(
    in certificate: Data
  ) throws -> Bool {
    let identifier = DerEncoder.objectIdentifier(SignOids.keyUsage)
    guard
      let keyUsage = try Self.certificateExtensions(in: certificate)
        .first(where: { $0.oid == identifier })
    else {
      return true
    }
    let bits = try Self.onlyElement(
      in: keyUsage.value,
      tag: DerValues.tagBitString
    )
    let content = DerReader(keyUsage.value).contentData(of: bits)
    guard
      let unusedBits = content.first,
      unusedBits < UInt8.bitWidth,
      let firstUsageByte = content.dropFirst().first,
      let lastUsageByte = content.last
    else {
      throw ValidationFailure.malformed
    }
    let unusedMask = UInt8.max >> (UInt8.bitWidth - Int(unusedBits))
    guard lastUsageByte & unusedMask == 0 else {
      throw ValidationFailure.malformed
    }
    let digitalSignature = UInt8(1) << (UInt8.bitWidth - 1)
    return firstUsageByte & digitalSignature != 0
  }

  /// Reads the responder's `id-pkix-ocsp-nocheck` extension exactly.
  private static func hasOcspNoCheckExtension(in certificate: Data) throws -> Bool {
    let noCheck = DerEncoder.objectIdentifier(SignOids.ocspNoCheck)
    for extensionValue in try Self.certificateExtensions(in: certificate)
    where extensionValue.oid == noCheck {
      _ = try Self.onlyElement(in: extensionValue.value, tag: DerValues.tagNull)
      return true
    }
    return false
  }

  /// Extracts unique extensions from a syntactically complete X.509 certificate.
  private static func certificateExtensions(in certificate: Data) throws -> [Extension] {
    let outer = try Self.onlyElement(in: certificate, tag: DerValues.tagSequence)
    var certificateReader = DerReader(certificate, within: outer)
    let tbs = try Self.requiredElement(
      from: &certificateReader,
      tag: DerValues.tagSequence
    )
    _ = try Self.requiredElement(
      from: &certificateReader,
      tag: DerValues.tagSequence
    )
    _ = try Self.requiredElement(
      from: &certificateReader,
      tag: DerValues.tagBitString
    )
    guard certificateReader.isAtEnd else {
      throw ValidationFailure.malformed
    }

    var reader = DerReader(certificate, within: tbs)
    var first = try Self.requiredElement(from: &reader)
    if first.tag == DerValues.tagContext0Constructed {
      first = try Self.requiredElement(from: &reader)
    }
    guard first.tag == DerValues.tagInteger else { throw ValidationFailure.malformed }
    _ = try Self.requiredElement(from: &reader, tag: DerValues.tagSequence)
    _ = try Self.requiredElement(from: &reader, tag: DerValues.tagSequence)
    _ = try Self.requiredElement(from: &reader, tag: DerValues.tagSequence)
    _ = try Self.requiredElement(from: &reader, tag: DerValues.tagSequence)
    _ = try Self.requiredElement(from: &reader, tag: DerValues.tagSequence)
    return try Self.certificateTrailingExtensions(in: certificate, reader: &reader)
  }

  /// Parses the optional issuer/subject IDs and extensions of a certificate.
  private static func certificateTrailingExtensions(
    in certificate: Data,
    reader: inout DerReader
  ) throws -> [Extension] {
    var extensions: [Extension] = []
    var foundExtensions = false
    while let trailing = reader.next() {
      switch trailing.tag {
      case DerValues.tagContext1Primitive, DerValues.tagContext2Primitive:
        continue

      case DerValues.tagContext3Constructed:
        guard !foundExtensions else { throw ValidationFailure.malformed }
        extensions = try Self.extensions(in: certificate, wrapper: trailing)
        try Self.rejectDuplicateExtensionIdentifiers(extensions)
        foundExtensions = true

      default:
        throw ValidationFailure.malformed
      }
    }
    guard reader.isAtEnd else { throw ValidationFailure.malformed }
    return extensions
  }

  /// Rejects certificates that name an extension more than once.
  private static func rejectDuplicateExtensionIdentifiers(
    _ extensions: [Extension]
  ) throws {
    var identifiers: Set<Data> = []
    for extensionValue in extensions {
      guard identifiers.insert(extensionValue.oid).inserted else {
        throw ValidationFailure.malformed
      }
    }
  }

  /// Maps a verified signature AlgorithmIdentifier to Security's verifier.
  internal static func signatureAlgorithm(
    in encoded: Data,
    element: DerReader.Element
  ) throws -> SecKeyAlgorithm {
    var reader = DerReader(encoded, within: element)
    let oid = try Self.requiredElement(
      from: &reader,
      tag: DerValues.tagObjectIdentifier
    )
    let identifier = reader.data(of: oid)
    let parameters = reader.next()
    guard reader.isAtEnd else {
      throw ValidationFailure.unsupportedSignatureAlgorithm
    }
    if let algorithm = Self.ecdsaSignatureAlgorithms[identifier] {
      guard parameters == nil else { throw ValidationFailure.unsupportedSignatureAlgorithm }
      return algorithm
    }
    if let algorithm = Self.rsaSignatureAlgorithms[identifier] {
      try Self.requireNullParameters(parameters)
      return algorithm
    }
    throw ValidationFailure.unsupportedSignatureAlgorithm
  }

  /// Verifies the BasicOCSPResponse signature over its exact DER ResponseData.
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

  /// Requires the explicit NULL parameters used by RSA signature OIDs.
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

  /// The issuer Name normalized by Security for certificate relationship tests.
  internal static func issuer(of certificate: SecCertificate) -> Data? {
    SecCertificateCopyNormalizedIssuerSequence(certificate) as Data?
  }

  /// The subject Name normalized by Security for certificate relationship tests.
  internal static func subject(of certificate: SecCertificate) -> Data? {
    SecCertificateCopyNormalizedSubjectSequence(certificate) as Data?
  }
}
