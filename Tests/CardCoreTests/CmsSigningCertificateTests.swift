// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// Direct ESS signing-certificate attribute checks.
@Suite
internal struct CmsSigningCertificateTests {
  /// Tags used only to assemble synthetic CMS messages.
  private enum Tag {
    static let context0: UInt8 = 0xA0
  }

  private static let contentType = "1.2.840.113549.1.9.3"
  private static let data = "1.2.840.113549.1.7.1"
  private static let sha1 = "1.3.14.3.2.26"
  private static let sha256 = "2.16.840.1.101.3.4.2.1"
  private static let sha384 = "2.16.840.1.101.3.4.2.2"
  private static let sha512 = "2.16.840.1.101.3.4.2.3"
  private static let signedData = "1.2.840.113549.1.7.2"
  private static let signingCertificate = "1.2.840.113549.1.9.16.2.12"
  private static let signingCertificateV2 = "1.2.840.113549.1.9.16.2.47"

  /// A locally generated ECDSA RFC 3161 token with ESSCertIDv2.
  private static let token = Self.decode(
    """
    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
    1qOUqQgGIjMZvFY=
    """
  )

  /// The exact signer certificate referenced by the fixture's ESS hash.
  private static let signer = Self.decode(
    """
    MIIBszCCAVigAwIBAgIUMHfE/GmdSvG3+CQRxHSnFzfP2IwwCgYIKoZIzj0EAwIwHDEaMBgGA1UE
    AwwRUmVGaW5lSUQgVGVzdCBUU0EwHhcNMjYwODA0MDc1MzI1WhcNMzYwODAxMDc1MzI1WjAcMRow
    GAYDVQQDDBFSZUZpbmVJRCBUZXN0IFRTQTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEma/2Y8
    UqzBdNi9vlLoFQ+WHFW8PCTu67N0kmhjl18Eu0kEjTrtF6y5wF1VXf9ktFdnUJX+Rz6FES49kwG7
    cDujeDB2MB0GA1UdDgQWBBTY+L64mtIcQMUST9Jv2XCaRNeLmzAfBgNVHSMEGDAWgBTY+L64mtIc
    QMUST9Jv2XCaRNeLmzAMBgNVHRMBAf8EAjAAMA4GA1UdDwEB/wQEAwIGwDAWBgNVHSUBAf8EDDAK
    BggrBgEFBQcDCDAKBggqhkjOPQQDAgNJADBGAiEAwvyfmlibx6Pf8KmrY7VfgYwxbr56A80RBza/
    J4cPYlECIQCYsi5iogIH1DrFGEDBDrUrjaanfMOXp8GithjIM97ohg==
    """
  )

  /// A hash AlgorithmIdentifier with absent parameters.
  private static func algorithm(_ oid: String) -> Data {
    DerEncoder.sequence([DerEncoder.objectIdentifier(oid)])
  }

  /// One CMS Attribute.
  private static func attribute(oid: String, value: Data) -> Data {
    DerEncoder.sequence([
      DerEncoder.objectIdentifier(oid),
      DerEncoder.setOf([value]),
    ])
  }

  /// Base64 fixture text with its line breaks ignored.
  private static func decode(_ encoded: String) -> Data {
    Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) ?? Data()
  }

  /// A display name for an internal digest-algorithm value.
  private static func name(
    of algorithm: CmsSigningCertificate.DigestAlgorithm
  ) -> String {
    switch algorithm {
    case .sha1:
      return "sha1"

    case .sha256:
      return "sha256"

    case .sha384:
      return "sha384"

    case .sha512:
      return "sha512"
    }
  }

  /// A synthetic CMS token carrying exactly the supplied signed attributes.
  private static func token(attributes: [Data]) -> Data {
    let signedAttributes = DerEncoder.tlv(
      Tag.context0, Data(attributes.joined())
    )
    let signerInfo = DerEncoder.sequence([
      DerEncoder.integer(1),
      DerEncoder.sequence([]),
      DerEncoder.sequence([]),
      signedAttributes,
    ])
    let body = DerEncoder.sequence([
      DerEncoder.integer(1),
      DerEncoder.setOf([]),
      DerEncoder.sequence([]),
      DerEncoder.setOf([signerInfo]),
    ])
    return DerEncoder.sequence([
      DerEncoder.objectIdentifier(Self.signedData),
      DerEncoder.tlv(Tag.context0, body),
    ])
  }

  /// A v1 or v2 signing-certificate attribute with one certificate ID.
  private static func signingAttribute(
    oid: String,
    digest: Data,
    algorithm: String? = nil
  ) -> Data {
    var fields: [Data] = []
    if let algorithm {
      fields.append(Self.algorithm(algorithm))
    }
    fields.append(DerEncoder.octetString(digest))
    let identifier = DerEncoder.sequence(fields)
    let value = DerEncoder.sequence([
      DerEncoder.sequence([identifier])
    ])
    return Self.attribute(oid: oid, value: value)
  }

  @Test
  internal func fixtureEssReferenceIdentifiesItsSigner() throws {
    try CmsSigningCertificate.verify(
      token: Self.token, certificate: Self.signer
    )
    let reference = try CmsSigningCertificate.reference(in: Self.token)
    #expect(Self.name(of: reference.algorithm) == "sha256")
  }

  @Test
  internal func aDifferentCertificateDoesNotMatchTheSignedHash() {
    var different = Self.signer
    different[different.startIndex] ^= 1
    #expect(throws: CmsSigningCertificate.Failure.mismatch) {
      try CmsSigningCertificate.verify(
        token: Self.token, certificate: different
      )
    }
  }

  @Test
  internal func malformedCmsIsRejected() {
    #expect(throws: CmsSigningCertificate.Failure.malformed) {
      _ = try CmsSigningCertificate.reference(in: Data("not cms".utf8))
    }
  }

  @Test
  internal func signingCertificateAttributeIsRequired() {
    let unrelated = Self.attribute(
      oid: Self.contentType,
      value: DerEncoder.objectIdentifier(Self.data)
    )
    #expect(throws: CmsSigningCertificate.Failure.malformed) {
      _ = try CmsSigningCertificate.reference(
        in: Self.token(attributes: [unrelated])
      )
    }
  }

  @Test
  internal func duplicateSigningCertificateAttributesAreRejected() {
    let attribute = Self.signingAttribute(
      oid: Self.signingCertificateV2,
      digest: Data(repeating: 1, count: 32)
    )
    #expect(throws: CmsSigningCertificate.Failure.malformed) {
      _ = try CmsSigningCertificate.reference(
        in: Self.token(attributes: [attribute, attribute])
      )
    }
  }

  @Test
  internal func omittedDigestAlgorithmsUseTheirSpecifiedDefaults() throws {
    let versionOne = Self.signingAttribute(
      oid: Self.signingCertificate,
      digest: Data(repeating: 1, count: 20)
    )
    let versionTwo = Self.signingAttribute(
      oid: Self.signingCertificateV2,
      digest: Data(repeating: 2, count: 32)
    )
    let first = try CmsSigningCertificate.reference(
      in: Self.token(attributes: [versionOne])
    )
    let second = try CmsSigningCertificate.reference(
      in: Self.token(attributes: [versionTwo])
    )
    #expect(Self.name(of: first.algorithm) == "sha1")
    #expect(Self.name(of: second.algorithm) == "sha256")
  }

  @Test
  internal func supportedExplicitDigestAlgorithmsAreParsed() throws {
    let algorithms = [
      (Self.sha1, "sha1"),
      (Self.sha256, "sha256"),
      (Self.sha384, "sha384"),
      (Self.sha512, "sha512"),
    ]
    for (oid, expected) in algorithms {
      let parsed = try CmsSigningCertificate.digestAlgorithm(
        Self.algorithm(oid)
      )
      #expect(Self.name(of: parsed) == expected)
    }
  }

  @Test
  internal func unsupportedDigestAlgorithmIsRejected() {
    #expect(throws: CmsSigningCertificate.Failure.unsupportedHash) {
      _ = try CmsSigningCertificate.digestAlgorithm(
        Self.algorithm("1.2.3.4")
      )
    }
  }
}
