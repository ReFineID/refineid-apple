// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Direct authentication tests for complete, issuer-signed CRLs.
@Suite
internal struct CertificateRevocationListTests {
  /// All six promised RSA/ECDSA hash combinations verify directly.
  @Test(arguments: CertificateRevocationListFixtures.SignatureKind.allCases)
  internal func supportedSignatureAlgorithm(
    _ kind: CertificateRevocationListFixtures.SignatureKind
  ) throws {
    let material = try material(kind: kind)

    let validity = try validate(material.crl, material: material)

    #expect(validity.encoded == material.crl)
    #expect(validity.thisUpdate < material.currentTime)
    #expect(validity.nextUpdate > material.currentTime)
  }

  /// Standard X509 CRL PEM input is decoded and returned as canonical DER.
  @Test
  internal func pemInputReturnsAuthenticatedDer() throws {
    let material = try material()

    let validity = try validate(material.crlPem, material: material)

    #expect(validity.encoded == material.crl)
  }

  /// An exact target serial in an authenticated CRL is rejected.
  @Test
  internal func listedTargetSerialIsRevoked() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.listsTargetSerial = true
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.revoked) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// A signature mutation cannot become validation material.
  @Test
  internal func invalidSignatureIsRejected() throws {
    let material = try material()
    var crl = material.crl
    crl[crl.index(before: crl.endIndex)] ^= 1

    #expect(throws: CertificateRevocationList.ValidationFailure.signatureInvalid) {
      _ = try validate(crl, material: material)
    }
  }

  /// A different supplied issuer is rejected before its CRL key is trusted.
  @Test
  internal func issuerNameMismatchIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.crlIssuerCommonName = "Different CRL Issuer"
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.issuerMismatch) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// A CA key without cRLSign is not authorized to issue revocation lists.
  @Test
  internal func issuerWithoutCrlSignIsRejected() throws {
    let material = try CertificateRevocationListFixtures.make(
      kind: .ecdsaSha256,
      options: .standard,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .withoutCrlSigning
    )

    #expect(throws: CertificateRevocationList.ValidationFailure.issuerUnauthorized) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// An omitted KeyUsage does not restrict the CA key; RFC 5280 only requires
  /// cRLSign when the extension is present.
  @Test
  internal func issuerWithoutKeyUsageCanSignCrl() throws {
    let material = try CertificateRevocationListFixtures.make(
      kind: .ecdsaSha256,
      options: .standard,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .absent
    )

    _ = try validate(material.crl, material: material)
  }

  /// Equal issuer names do not hide a leaf signed by a different key.
  @Test
  internal func sameNameWrongKeyIssuerIsRejected() throws {
    let material = try CertificateRevocationListFixtures.make(
      kind: .ecdsaSha256,
      options: .standard,
      targetSignedByWrongKey: true,
      issuerKeyUsage: .crlSigning
    )

    #expect(throws: CertificateRevocationList.ValidationFailure.issuerMismatch) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// thisUpdate after the explicit verification time is rejected.
  @Test
  internal func futureListIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.thisUpdate = "20260701000000Z"
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.listFromFuture) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// nextUpdate at or before the explicit verification time is rejected.
  @Test
  internal func expiredListIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.nextUpdate = "20260515000000Z"
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.listExpired) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// This product does not store a CRL without an authenticated freshness end.
  @Test
  internal func missingNextUpdateIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.includesNextUpdate = false
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.nextUpdateMissing) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// Unknown critical extension semantics fail closed.
  @Test
  internal func unsupportedCriticalExtensionIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    let extensionValue = CertificateRevocationListFixtures.extensionValue(
      oid: CertificateRevocationListFixtures.unknownExtensionOid,
      critical: true,
      value: DerEncoder.sequence([])
    )
    options.crlExtensions = [extensionValue]
    let material = try material(options: options)

    #expect(
      throws: CertificateRevocationList.ValidationFailure
        .unsupportedCriticalExtension
    ) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// deltaCRLIndicator is never accepted as a complete list.
  @Test
  internal func deltaListIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    let extensionValue = CertificateRevocationListFixtures.extensionValue(
      oid: CertificateRevocationListFixtures.deltaCrlIndicatorOid,
      critical: true,
      value: DerEncoder.integer(1)
    )
    options.crlExtensions = [extensionValue]
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.deltaUnsupported) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// indirectCRL in IssuingDistributionPoint is rejected explicitly.
  @Test
  internal func indirectListIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    let indirectField = DerEncoder.tlv(
      CertificateRevocationListFixtures.tagContext4Primitive,
      Data([CertificateRevocationListFixtures.booleanTrue])
    )
    let indirect = DerEncoder.sequence([indirectField])
    let extensionValue = CertificateRevocationListFixtures.extensionValue(
      oid: CertificateRevocationListFixtures.issuingDistributionPointOid,
      critical: true,
      value: indirect
    )
    options.crlExtensions = [extensionValue]
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.indirectUnsupported) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// Entry-level certificateIssuer also invokes indirect-CRL semantics.
  @Test
  internal func indirectEntryIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    options.listsTargetSerial = true
    let extensionValue = CertificateRevocationListFixtures.extensionValue(
      oid: CertificateRevocationListFixtures.certificateIssuerOid,
      critical: true,
      value: DerEncoder.sequence([])
    )
    options.entryExtensions = [extensionValue]
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.indirectUnsupported) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// A distribution-point scope cannot prove absence for every certificate.
  @Test
  internal func scopedIssuingDistributionPointIsRejected() throws {
    var options = CertificateRevocationListFixtures.Options.standard
    let scopedField = DerEncoder.tlv(
      CertificateRevocationListFixtures.tagContext1Primitive,
      Data([CertificateRevocationListFixtures.booleanTrue])
    )
    let scoped = DerEncoder.sequence([scopedField])
    let extensionValue = CertificateRevocationListFixtures.extensionValue(
      oid: CertificateRevocationListFixtures.issuingDistributionPointOid,
      critical: true,
      value: scoped
    )
    options.crlExtensions = [extensionValue]
    let material = try material(options: options)

    #expect(throws: CertificateRevocationList.ValidationFailure.scopeUnsupported) {
      _ = try validate(material.crl, material: material)
    }
  }

  /// DER trailing data is not ignored.
  @Test
  internal func trailingBytesAreRejected() throws {
    let material = try material()
    var crl = material.crl
    crl.append(0)

    #expect(throws: CertificateRevocationList.ValidationFailure.malformed) {
      _ = try validate(crl, material: material)
    }
  }

  /// Generates the default fast P-256 material.
  private func material() throws -> CertificateRevocationListFixtures.Material {
    try material(options: .standard)
  }

  /// Generates P-256 material with controlled CRL fields.
  private func material(
    options: CertificateRevocationListFixtures.Options
  ) throws -> CertificateRevocationListFixtures.Material {
    try CertificateRevocationListFixtures.make(
      kind: .ecdsaSha256,
      options: options,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .crlSigning
    )
  }

  /// Generates standard material for one signature algorithm.
  private func material(
    kind: CertificateRevocationListFixtures.SignatureKind
  ) throws -> CertificateRevocationListFixtures.Material {
    try CertificateRevocationListFixtures.make(
      kind: kind,
      options: .standard,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .crlSigning
    )
  }

  /// Calls the public validator with one material set's fixed context.
  private func validate(
    _ crl: Data,
    material: CertificateRevocationListFixtures.Material
  ) throws -> CertificateRevocationList.Validity {
    try CertificateRevocationList.validate(
      crl: crl,
      certificate: material.certificate,
      issuerCertificate: material.issuerCertificate,
      currentTime: material.currentTime
    )
  }
}
