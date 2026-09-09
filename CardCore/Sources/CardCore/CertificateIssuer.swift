// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Verifies one direct X.509 certificate-issuer relationship.
///
/// Normal certificates retain the platform's complete basic-X.509 evaluation,
/// including critical extensions and path constraints. An exact
/// `errSecCertificateRevoked` enters a narrow direct-relationship fallback
/// because that platform result alone does not answer the issuer question. The
/// fallback checks the exact TBSCertificate signature, issuer authorization,
/// names, and validity. It only answers that relationship: callers separately
/// enforce revocation status, and release signing still refuses revoked status.
public enum CertificateIssuer {
  /// What the platform's complete path evaluation concluded.
  internal enum PlatformVerdict {
    /// The direct path is valid.
    case accepted

    /// The path failed for any other reason.
    case rejected

    /// The platform reported exact certificate revocation.
    case revoked
  }

  /// One structurally complete certificate and its signed fields.
  internal struct Parsed {
    /// The platform certificate handle used only for its public key and names.
    internal let certificate: SecCertificate

    /// The exact certificate bytes.
    internal let encoded: Data

    /// The outer signature AlgorithmIdentifier.
    internal let signatureAlgorithm: Data

    /// The signature bits, without the BIT STRING unused-bits octet.
    internal let signature: Data

    /// The exact TBSCertificate covered by the signature.
    internal let signedBytes: Data

    /// The TBSCertificate element within `encoded`.
    internal let tbs: DerReader.Element
  }

  /// Whether `issuer` directly issued `certificate` at `date`.
  public static func isDirectlyIssued(
    _ certificate: Data,
    by issuer: Data,
    at date: Date
  ) -> Bool {
    guard let subject = Self.parsed(certificate),
      let authority = Self.parsed(issuer)
    else {
      return false
    }
    switch Self.platformVerdict(subject: subject, issuer: authority, at: date) {
    case .accepted:
      return true

    case .rejected:
      return false

    case .revoked:
      return Self.cryptographicallyDirectlyIssued(
        subject, by: authority, at: date
      )
    }
  }

  /// Whether the platform accepts the relationship without the revoked fallback.
  ///
  /// Delegated OCSP responder authorization uses this stricter path: the
  /// fallback exists to expose a target certificate's status, not to excuse
  /// status already attached to the certificate signing that response.
  internal static func isDirectlyIssuedByPlatform(
    _ certificate: Data,
    by issuer: Data,
    at date: Date
  ) -> Bool {
    guard
      let subject = Self.parsed(certificate),
      let authority = Self.parsed(issuer)
    else {
      return false
    }
    guard
      case .accepted = Self.platformVerdict(
        subject: subject, issuer: authority, at: date
      )
    else {
      return false
    }
    return true
  }

  /// Direct proof used only after the platform reports exact revocation.
  internal static func cryptographicallyDirectlyIssued(
    _ subject: Parsed,
    by authority: Parsed,
    at date: Date
  ) -> Bool {
    guard
      Self.namesMatch(subject: subject, issuer: authority),
      Self.isValid(subject, at: date),
      Self.isValid(authority, at: date),
      Self.isPermittedEndEntity(subject),
      Self.canIssueCertificates(authority),
      let algorithm = try? CertificateRevocationList.signatureAlgorithm(
        from: subject.signatureAlgorithm
      )
    else {
      return false
    }
    return CertificateRevocationList.signatureIsValid(
      subject.signature,
      over: subject.signedBytes,
      with: authority.certificate,
      algorithm: algorithm
    )
  }

  /// Direct proof test boundary that performs no platform trust evaluation.
  internal static func cryptographicallyDirectlyIssued(
    _ certificate: Data,
    by issuer: Data,
    at date: Date
  ) -> Bool {
    guard
      let subject = Self.parsed(certificate),
      let authority = Self.parsed(issuer)
    else {
      return false
    }
    return Self.cryptographicallyDirectlyIssued(
      subject, by: authority, at: date
    )
  }
}
