// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  @testable import CardCore
  import Foundation
  import Testing

  /// CMS, ESS, EKU and trust checks over a fixed RFC 3161 fixture.
  @Suite
  internal struct TimestampTokenVerifierTests {
    /// A locally generated ECDSA RFC 3161 token.
    ///
    /// Its TSTInfo is over the SHA-384 digest of empty input and its
    /// certificate is restricted to timestamping by a critical EKU.
    private static let token = Self.decode(
      """
      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
      1qOUqQgGIjMZvFY=
      """
    )

    /// The exact signer certificate, used as the test trust anchor.
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

    /// X.509 BasicConstraints `cA = TRUE` field.
    private static let certificateAuthorityConstraint = DerEncoder.tlv(
      DerValues.tagBoolean, Data([DerValues.booleanTrue])
    )

    /// X.509 BasicConstraints `cA = TRUE`.
    private static let certificateAuthorityBasicConstraints = DerEncoder.sequence(
      [Self.certificateAuthorityConstraint]
    )

    /// X.509 BasicConstraints default to an end entity when empty.
    private static let endEntityBasicConstraints = DerEncoder.sequence([])

    /// KeyUsage bits for a normal signing leaf and a CA-only key.
    private static let signingKeyUsage = DerEncoder.tlv(
      DerValues.tagBitString,
      Data([0, UInt8(1) << UInt8(7)])
    )
    private static let certificateAuthorityKeyUsage = DerEncoder.tlv(
      DerValues.tagBitString,
      Data([0, UInt8(1) << UInt8(2)])
    )
    private static let malformedUnusedKeyUsage = DerEncoder.tlv(
      DerValues.tagBitString,
      Data([7, UInt8(1) << UInt8(6)])
    )

    /// Base64 fixture text with its line breaks ignored.
    private static func decode(_ encoded: String) -> Data {
      Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) ?? Data()
    }

    /// A structurally sufficient certificate carrying controlled profile
    /// extensions.
    ///
    /// The profile check runs before the caller anchor is used.
    private static func timestampSignerCertificate(
      basicConstraints: Data,
      keyUsage: Data
    ) -> Data {
      let extensions = DerEncoder.sequence([
        DerEncoder.sequence([
          DerEncoder.objectIdentifier(SignOids.extendedKeyUsage),
          DerEncoder.tlv(
            DerValues.tagBoolean, Data([DerValues.booleanTrue])
          ),
          DerEncoder.octetString(
            DerEncoder.sequence([
              DerEncoder.objectIdentifier(SignOids.timestampingKeyPurpose)
            ])
          ),
        ]),
        DerEncoder.sequence([
          DerEncoder.objectIdentifier(SignOids.basicConstraints),
          DerEncoder.octetString(basicConstraints),
        ]),
        DerEncoder.sequence([
          DerEncoder.objectIdentifier(SignOids.keyUsage),
          DerEncoder.tlv(
            DerValues.tagBoolean, Data([DerValues.booleanTrue])
          ),
          DerEncoder.octetString(keyUsage),
        ]),
      ])
      let publicKey = DerEncoder.sequence([
        DerEncoder.sequence([]),
        DerEncoder.tlv(DerValues.tagBitString, Data([0, 1])),
      ])
      let tbs = DerEncoder.sequence([
        DerEncoder.integer(1),
        DerEncoder.sequence([]),
        DerEncoder.sequence([]),
        DerEncoder.sequence([]),
        DerEncoder.sequence([]),
        publicKey,
        DerEncoder.tlv(DerValues.tagContext3Constructed, extensions),
      ])
      return DerEncoder.sequence([tbs])
    }

    @Test
    internal func validSignatureAndExplicitAnchorAreAccepted() throws {
      let verified = try TimestampTokenVerifier.verify(
        Self.token, trustedCertificates: [Self.signer]
      )
      #expect(verified.token == Self.token)
      #expect(verified.signerCertificate == Self.signer)
      #expect(verified.embeddedCertificates.contains(Self.signer))
      #expect(verified.verifiedCertificateChain == [Self.signer])
      #expect(verified.trustedCertificate == Self.signer)
      #expect(verified.generatedAt == Date(timeIntervalSince1970: 1_785_830_005))
    }

    @Test
    internal func aTokenNeverFallsBackToSystemTrust() {
      #expect(throws: TimestampTokenVerifier.Failure.untrustedSigner) {
        _ = try TimestampTokenVerifier.verify(
          Self.token, trustedCertificates: []
        )
      }
    }

    @Test
    internal func aChangedCmsSignatureIsRejected() {
      var changed = Self.token
      if let last = changed.indices.last {
        changed[last] ^= 1
      }
      #expect(throws: TimestampTokenVerifier.Failure.invalidSignature) {
        _ = try TimestampTokenVerifier.verify(
          changed, trustedCertificates: [Self.signer]
        )
      }
    }

    @Test
    internal func malformedCmsIsRejectedBeforeTrust() {
      #expect(throws: TimestampTokenVerifier.Failure.malformed) {
        _ = try TimestampTokenVerifier.verify(
          Data("not cms".utf8), trustedCertificates: [Self.signer]
        )
      }
    }

    @Test
    internal func signerCertificateHasTheRequiredTimestampingEku() {
      #expect(
        CertificateFacts(der: Self.signer)?.hasTimestampingExtendedKeyUsage
          == true
      )
    }

    @Test
    internal func signerValidityUsesSignedGenerationTime() {
      let generationTime = Date(timeIntervalSince1970: 1_785_830_005)

      #expect(
        TimestampTokenVerifier.signerCertificateIsValid(
          Self.signer, at: generationTime
        )
      )
      #expect(
        !TimestampTokenVerifier.signerCertificateIsValid(
          Self.signer, at: generationTime.addingTimeInterval(-1)
        )
      )
    }

    @Test
    internal func signerProfileRejectsCaAndIncompatibleKeyUsageBeforeTrust() {
      let permitted = Self.timestampSignerCertificate(
        basicConstraints: Self.endEntityBasicConstraints,
        keyUsage: Self.signingKeyUsage
      )
      let certificateAuthority = Self.timestampSignerCertificate(
        basicConstraints: Self.certificateAuthorityBasicConstraints,
        keyUsage: Self.signingKeyUsage
      )
      let authorityKeyUsage = Self.timestampSignerCertificate(
        basicConstraints: Self.endEntityBasicConstraints,
        keyUsage: Self.certificateAuthorityKeyUsage
      )

      #expect(
        TimestampTokenVerifier.signerCertificateProfileIsValid(permitted)
      )
      #expect(
        !TimestampTokenVerifier.signerCertificateProfileIsValid(
          certificateAuthority
        )
      )
      #expect(
        !TimestampTokenVerifier.signerCertificateProfileIsValid(
          authorityKeyUsage
        )
      )
    }

    /// Declared unused KeyUsage bits must be zero.
    @Test
    internal func signerProfileRejectsNonzeroUnusedKeyUsageBits() {
      let malformed = Self.timestampSignerCertificate(
        basicConstraints: Self.endEntityBasicConstraints,
        keyUsage: Self.malformedUnusedKeyUsage
      )

      #expect(
        !TimestampTokenVerifier.signerCertificateProfileIsValid(malformed)
      )
    }
  }

#endif
