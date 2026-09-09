// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Refusal paths at the qualified-CMS public boundary.
extension QualifiedDocumentCmsTests {
  /// Empty or malformed signature values never reach CMS.
  @Test
  internal func malformedSignatureValuesAreRefused() throws {
    let ecdsa = try Self.identity(.ecdsaP384)
    let rsa = try Self.identity(.rsa3072)
    let ecdsaAttributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: ecdsa.certificate
    )
    let rsaAttributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: rsa.certificate
    )
    #expect(throws: QualifiedDocumentCms.AssemblyError.signatureMalformed) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: ecdsaAttributes,
        signatureValue: Data(),
        signerProfile: ecdsa.profile,
        signerCertificate: ecdsa.certificate,
        timestampTokens: []
      )
    }
    #expect(throws: QualifiedDocumentCms.AssemblyError.signatureMalformed) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: ecdsaAttributes,
        signatureValue: Data(repeating: 1, count: 3),
        signerProfile: ecdsa.profile,
        signerCertificate: ecdsa.certificate,
        timestampTokens: []
      )
    }
    #expect(throws: QualifiedDocumentCms.AssemblyError.signatureMalformed) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: rsaAttributes,
        signatureValue: Data(repeating: 1, count: 383),
        signerProfile: rsa.profile,
        signerCertificate: rsa.certificate,
        timestampTokens: []
      )
    }
  }

  /// RSA-2048 signatures must occupy the full 256-byte modulus width.
  @Test
  internal func malformedRsa2048SignatureValueIsRefused() throws {
    let identity = try Self.identity(.rsa2048)
    let attributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: identity.certificate
    )

    #expect(throws: QualifiedDocumentCms.AssemblyError.signatureMalformed) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: attributes,
        signatureValue: Data(repeating: 1, count: 255),
        signerProfile: identity.profile,
        signerCertificate: identity.certificate,
        timestampTokens: []
      )
    }
  }

  /// Unparseable certificates and certificate/profile mismatches fail closed.
  @Test
  internal func certificateProfileProblemsAreRefused() throws {
    let ecdsa = try Self.identity(.ecdsaP384)
    let rsa = try Self.identity(.rsa3072)
    let ecdsaAttributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: ecdsa.certificate
    )
    let rsaAttributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: rsa.certificate
    )
    #expect(
      throws: QualifiedDocumentCms.AssemblyError.certificateProfileMismatch
    ) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: ecdsaAttributes,
        signatureValue: Data(repeating: 1, count: 384),
        signerProfile: .rsa3072,
        signerCertificate: ecdsa.certificate,
        timestampTokens: []
      )
    }
    #expect(throws: QualifiedDocumentCms.AssemblyError.certificateUnparseable) {
      _ = try QualifiedDocumentCms.assemble(
        signedAttributesSet: rsaAttributes,
        signatureValue: Data(repeating: 1, count: 384),
        signerProfile: .rsa3072,
        signerCertificate: Data("not a certificate".utf8),
        timestampTokens: []
      )
    }
  }

  /// The assembler refuses attributes that cannot safely be retagged.
  @Test
  internal func malformedSignedAttributesAreRefused() throws {
    let identity = try Self.identity(.ecdsaP384)
    let attributes = QualifiedDocumentCms.signedAttributes(
      byteRangeDigest: Data(repeating: 0xA5, count: 48),
      signerCertificate: identity.certificate
    )
    let signature = try Self.signature(over: attributes, identity: identity)

    for malformed in [Data(), DerEncoder.sequence([]), DerEncoder.setOf([])] {
      #expect(
        throws: QualifiedDocumentCms.AssemblyError.signedAttributesMalformed
      ) {
        _ = try QualifiedDocumentCms.assemble(
          signedAttributesSet: malformed,
          signatureValue: signature,
          signerProfile: identity.profile,
          signerCertificate: identity.certificate,
          timestampTokens: []
        )
      }
    }
  }
}
