// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The ESS signing-certificate attribute binding a CMS signature to
/// its certificate (RFC 2634 and RFC 5035).
internal enum CmsSigningCertificate {
  /// Why the signed binding cannot identify the actual signer.
  internal enum Failure: Error, Equatable {
    /// The attribute or its ASN.1 structure is absent or ambiguous.
    case malformed

    /// The signed certificate hash or optional issuer/serial differs.
    case mismatch

    /// The attribute names an unsupported certificate hash.
    case unsupportedHash
  }

  /// The supported certificate-digest algorithms.
  internal enum DigestAlgorithm {
    case sha1
    case sha256
    case sha384
    case sha512
  }

  /// One ESSCertID or ESSCertIDv2.
  internal struct Reference {
    internal let algorithm: DigestAlgorithm
    internal let digest: Data
    internal let issuerSerial: Data?
  }

  /// Verifies the token's signed ESS reference against `certificate`.
  internal static func verify(token: Data, certificate: Data) throws {
    let reference = try Self.reference(in: token)
    let actual = Self.digest(certificate, with: reference.algorithm)
    guard ConstantTimeComparison.equal(reference.digest, actual) else {
      throw Failure.mismatch
    }
    if let issuerSerial = reference.issuerSerial {
      guard
        let facts = CertificateFacts(der: certificate),
        Self.matches(issuerSerial: issuerSerial, certificate: facts)
      else {
        throw Failure.mismatch
      }
    }
  }

  /// Finds the one signing-certificate attribute in the SignerInfo.
  internal static func reference(in token: Data) throws -> Reference {
    let attributes = try Self.signedAttributes(in: token)
    var versionOne: DerReader.Element?
    var versionTwo: DerReader.Element?
    var reader = DerReader(token, within: attributes)
    while let attribute = reader.next() {
      guard attribute.tag == DerValues.tagSequence else { throw Failure.malformed }
      var parts = DerReader(token, within: attribute)
      guard
        let oid = parts.next(),
        oid.tag == DerValues.tagObjectIdentifier,
        let values = parts.next(),
        values.tag == DerValues.tagSet,
        parts.isAtEnd
      else {
        throw Failure.malformed
      }
      let encodedOid = parts.data(of: oid)
      if encodedOid == DerEncoder.objectIdentifier(SignOids.signingCertificate) {
        guard versionOne == nil else { throw Failure.malformed }
        versionOne = values
      } else if encodedOid
        == DerEncoder.objectIdentifier(SignOids.signingCertificateV2)
      {
        guard versionTwo == nil else { throw Failure.malformed }
        versionTwo = values
      }
    }
    guard reader.isAtEnd, versionOne == nil || versionTwo == nil else {
      throw Failure.malformed
    }
    if let versionTwo {
      return try Self.reference(in: versionTwo, token: token, versionTwo: true)
    }
    if let versionOne {
      return try Self.reference(in: versionOne, token: token, versionTwo: false)
    }
    throw Failure.malformed
  }

  /// Hashes the complete DER certificate as ESS requires.
  private static func digest(_ certificate: Data, with algorithm: DigestAlgorithm) -> Data {
    switch algorithm {
    case .sha1:
      return Data(Insecure.SHA1.hash(data: certificate))

    case .sha256:
      return Data(SHA256.hash(data: certificate))

    case .sha384:
      return Data(SHA384.hash(data: certificate))

    case .sha512:
      return Data(SHA512.hash(data: certificate))
    }
  }
}
