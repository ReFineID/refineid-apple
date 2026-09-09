// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Direct CMS CertificateSet extraction checks for timestamp chains.
@Suite
internal struct CmsCertificatesTests {
  /// Tags used only to assemble synthetic CMS fixtures.
  private enum Tag {
    static let context0: UInt8 = 0xA0
    static let context1: UInt8 = 0xA1
    static let sequence: UInt8 = 0x30
    static let set: UInt8 = 0x31
  }

  /// id-signedData.
  private static let signedData = "1.2.840.113549.1.7.2"

  /// A minimal SignedData with one caller-provided CertificateSet body.
  private static func token(
    certificates: Data?,
    contentType: String = Self.signedData,
    revocations: Data? = nil,
    trailingSignedData: Data = Data()
  ) -> Data {
    var fields = [
      DerEncoder.integer(1),
      DerEncoder.tlv(Tag.set, Data()),
      DerEncoder.sequence([DerEncoder.objectIdentifier("1.2.3")]),
    ]
    if let certificates {
      fields.append(DerEncoder.tlv(Tag.context0, certificates))
    }
    if let revocations {
      fields.append(DerEncoder.tlv(Tag.context1, revocations))
    }
    fields.append(DerEncoder.tlv(Tag.set, Data()))
    fields.append(trailingSignedData)
    let signed = DerEncoder.sequence(fields)
    return DerEncoder.sequence([
      DerEncoder.objectIdentifier(contentType),
      DerEncoder.tlv(Tag.context0, signed),
    ])
  }

  /// Every ordinary certificate is returned verbatim and non-certificate
  /// CertificateChoices are ignored.
  @Test
  internal func ordinaryCertificatesAreReturnedVerbatim() {
    let first = DerEncoder.sequence([DerEncoder.integer(1)])
    let second = DerEncoder.sequence([DerEncoder.integer(2)])
    let attributeCertificate = DerEncoder.tlv(
      Tag.context0,
      DerEncoder.integer(3)
    )
    let token = Self.token(
      certificates: first + attributeCertificate + second
    )

    #expect(CmsCertificates.inside(token) == [first, second])
  }

  /// A lookalike ContentInfo or trailing top-level bytes never supplies
  /// trust material.
  @Test
  internal func malformedOrWrongContentInfoReturnsNoCertificates() {
    let certificate = DerEncoder.sequence([DerEncoder.integer(1)])
    let wrongType = Self.token(
      certificates: certificate,
      contentType: "1.2.840.113549.1.7.1"
    )
    var trailing = Self.token(certificates: certificate)
    trailing.append(0)
    let malformedSignedData = Self.token(
      certificates: certificate,
      trailingSignedData: DerEncoder.integer(9)
    )

    #expect(CmsCertificates.inside(wrongType).isEmpty)
    #expect(CmsCertificates.inside(trailing).isEmpty)
    #expect(CmsCertificates.inside(malformedSignedData).isEmpty)
    #expect(CmsCertificates.inside(Data("not cms".utf8)).isEmpty)
  }

  /// Compacting a verified token removes only its unsigned CertificateSet.
  @Test
  internal func removingCertificatesPreservesEveryOtherSignedDataField() throws {
    let certificate = DerEncoder.sequence([DerEncoder.integer(1)])
    let revocations = DerEncoder.sequence([DerEncoder.integer(2)])
    let token = Self.token(
      certificates: certificate,
      revocations: revocations
    )
    let expected = Self.token(
      certificates: nil,
      revocations: revocations
    )

    let compact = try #require(
      CmsCertificates.removingCertificates(from: token)
    )

    #expect(compact == expected)
    #expect(compact.count < token.count)
    #expect(CmsCertificates.inside(compact).isEmpty)
    #expect(CmsCertificates.removingCertificates(from: compact) == nil)
  }
}
