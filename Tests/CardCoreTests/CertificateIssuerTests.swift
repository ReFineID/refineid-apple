// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security
import Testing

@testable import CardCore

/// Direct certificate relationship checks behind the revoked-only fallback.
@Suite
internal struct CertificateIssuerTests {
  /// A point inside both deterministic fixture certificates' validity.
  private static let validDate = Date(timeIntervalSince1970: 1_785_830_395)

  /// A point before both deterministic fixture certificates' validity.
  private static let earlyDate = Date(timeIntervalSince1970: 1_700_000_000)

  @Test
  internal func exactIssuerSignatureIsAccepted() {
    #expect(
      CertificateIssuer.isDirectlyIssued(
        OcspResponseTests.certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.validDate
      )
    )
    #expect(
      CertificateIssuer.cryptographicallyDirectlyIssued(
        OcspResponseTests.certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.validDate
      )
    )
  }

  @Test
  internal func tamperedCertificateSignatureIsRejected() {
    var certificate = OcspResponseTests.certificate
    certificate[certificate.index(before: certificate.endIndex)] ^= 1

    #expect(
      !CertificateIssuer.isDirectlyIssued(
        certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.validDate
      )
    )
    #expect(
      !CertificateIssuer.cryptographicallyDirectlyIssued(
        certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.validDate
      )
    )
  }

  @Test
  internal func noncanonicalOptionalAlgorithmFieldIsRejected() {
    let noncanonicalEmptyNull = Data([
      DerValues.tagNull,
      DerValues.longFormMask | UInt8(1),
      DerValues.booleanFalse,
    ])
    let encoded = DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256),
      noncanonicalEmptyNull,
    ])
    guard
      let sequence = CertificateIssuer.onlyElement(
        in: encoded,
        tag: DerValues.tagSequence
      )
    else {
      Issue.record("Outer sequence must parse")
      return
    }
    var reader = DerReader(encoded, within: sequence)
    let identifier = CertificateIssuer.nextElement(
      from: &reader,
      in: encoded,
      tag: DerValues.tagObjectIdentifier
    )
    let malformed = CertificateIssuer.nextElement(
      from: &reader,
      in: encoded
    )

    #expect(identifier != nil)
    #expect(malformed == nil)
    #expect(!reader.isAtEnd)
  }

  @Test
  internal func nonCaCannotIssueCertificate() {
    guard
      let leaf = CertificateIssuer.parsed(OcspResponseTests.certificate),
      let issuer = CertificateIssuer.parsed(
        OcspResponseTests.issuerCertificate
      )
    else {
      Issue.record("Fixture certificates must parse")
      return
    }

    #expect(!CertificateIssuer.canIssueCertificates(leaf))
    #expect(CertificateIssuer.canIssueCertificates(issuer))
    #expect(CertificateIssuer.isPermittedEndEntity(leaf))
    #expect(!CertificateIssuer.isPermittedEndEntity(issuer))
  }

  @Test
  internal func explicitFalseBasicConstraintIsEndEntity() throws {
    let material = try CertificateRevocationListFixtures.make(
      kind: .rsaSha256,
      options: .standard,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .crlSigning,
      explicitFalseBasicConstraint: true
    )
    guard let leaf = CertificateIssuer.parsed(material.certificate) else {
      Issue.record("Generated target certificate must parse")
      return
    }

    #expect(CertificateIssuer.isPermittedEndEntity(leaf))
    #expect(!CertificateIssuer.canIssueCertificates(leaf))
  }

  @Test
  internal func relationshipOutsideValidityIsRejected() {
    #expect(
      !CertificateIssuer.cryptographicallyDirectlyIssued(
        OcspResponseTests.certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.earlyDate
      )
    )
  }

  @Test
  internal func validityBoundariesAreInclusive() {
    guard
      let leaf = CertificateIssuer.parsed(OcspResponseTests.certificate),
      let notBefore =
        SecCertificateCopyNotValidBeforeDate(leaf.certificate) as Date?,
      let notAfter =
        SecCertificateCopyNotValidAfterDate(leaf.certificate) as Date?
    else {
      Issue.record("Fixture certificate must expose its validity")
      return
    }

    #expect(!CertificateIssuer.isValid(leaf, at: notBefore.addingTimeInterval(-1)))
    #expect(CertificateIssuer.isValid(leaf, at: notBefore))
    #expect(CertificateIssuer.isValid(leaf, at: notAfter))
    #expect(!CertificateIssuer.isValid(leaf, at: notAfter.addingTimeInterval(1)))
  }
}
