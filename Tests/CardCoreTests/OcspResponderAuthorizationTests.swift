// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// RFC 6960 delegated-responder authorization requirements.
@Suite
internal struct OcspResponderAuthorizationTests {
  /// Fixture decoding that keeps checked-in DER readable in source.
  private enum Fixture {
    /// Decodes an invariant base64 fixture without a forced unwrap.
    static func data(_ encoded: String) -> Data {
      Data(base64Encoded: encoded) ?? Data()
    }

    /// Validates one fixture with its associated response time.
    static func validate(_ response: Data) throws -> OcspResponse.Validity {
      try OcspResponse.validate(
        response: response,
        certificate: OcspResponseTests.certificate,
        issuerCertificate: OcspResponseTests.issuerCertificate,
        nonce: OcspResponseTests.nonce,
        currentTime: OcspResponderAuthorizationTests.currentTime
      )
    }
  }

  /// A CA-authorized responder with OCSP EKU and the nocheck extension.
  private static let responseWithNoCheck = Fixture.data(
    "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"
  )

  /// A response from a delegated EKU responder without nocheck.
  private static let responseWithoutNoCheck = Fixture.data(
    "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"
  )

  /// A direct-issuer child without id-kp-OCSPSigning.
  private static let responseWithoutOcspSigningEku = Fixture.data(
    "MIIFKAoBAKCCBSEwggUdBgkrBgEFBQcwAQEEggUOMIIFCjCB1aEkMCIxIDAeBgNVBAMMF1JlRmluZUlEIE9DU1AgVGVzdCBM"
      + "ZWFmGA8yMDI2MDgwNDA4MDg1MFowdzB1ME0wCQYFKw4DAhoFAAQUbxOaojSmpa7Q0ITX8H99z4O/6O0EFC5KkvLIdNZZZvn3"
      + "Indr84LPW7PKAhQdj7qaW4e2abvc54FdTi0m/rKd5oAAGA8yMDI2MDgwNDA4MDg1MFqgERgPMjAyNjA5MDMwODA4NTBaoSMw"
      + "ITAfBgkrBgEFBQcwAQIEEgQQtHFB4aFTUF7jaqWFJO0FCjANBgkqhkiG9w0BAQsFAAOCAQEAG1eUu+a2KFAP44FOfCAnDhP3"
      + "xQY6VVTVoqNne6Z3VcdhAkd0wchJCfc7pVO0aFMhcJtazpoNTHslmnWYgrGFgCByqZf3QYIxIwcTQpDlHmEv9oFl9FG11A1O"
      + "cA0dYRQTts3F5M6Ppf6D4S88dmm2drlGTqxRBnBf402V5j61f9Kf3U7x53Q1x1cu7YbVP+GYNlYLJpWi/sZsm4bhYBONtaWR"
      + "u5QNxfdf46I74DAgHbP38kYcuCuvivWWPIqgxirrLqZtrvNgrdbRIkZEOzPo0L6i4wOhonpopZbf2zzVQIJjoar/K54KguRZ"
      + "+BXYgejSCJa2cskthePKbeHkYzKse6CCAxowggMWMIIDEjCCAfqgAwIBAgIUHY+6mluHtmm73OeBXU4tJv6yneYwDQYJKoZI"
      + "hvcNAQELBQAwIDEeMBwGA1UEAwwVUmVGaW5lSUQgT0NTUCBUZXN0IENBMB4XDTI2MDgwNDA3NTkyNFoXDTI3MDgwNDA3NTky"
      + "NFowIjEgMB4GA1UEAwwXUmVGaW5lSUQgT0NTUCBUZXN0IExlYWYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDI"
      + "ch5n4JX00LIdb3v0RfeD8bgvn4XZRNxflAEes7VGE5uQ6VqWpeIgjVKwjFUninnLhKGvjauG2jOfhtsn1tmxCgZpHj4Tnu9P"
      + "0s3hkcShSp1UrOAZ/K/jDB7YSGWZoQl/vA4d0LzLtG1N2SX9J0+lOMbmwqkdsO5RZL8ZEusqBgQUX6nHB+VmoR2DfdwzMEiI"
      + "T0YMZBajBdyDHOOzY0Pv4xucCxOmpD/SDsZtKP3O4QA0CUBssQ1HBnbRRCf/YFg5HzkPROOVoPwiyHh1lXCs26pwYKmebIki"
      + "xTWraF+BPfpA3SFb5UDBpv+q+5N5XSFklpjzSmAEnxJIbxWDiNuBAgMBAAGjQjBAMB0GA1UdDgQWBBT9/HnEEqK84ujoj0Bg"
      + "ddwsY2GvUzAfBgNVHSMEGDAWgBQuSpLyyHTWWWb59yJ3a/OCz1uzyjANBgkqhkiG9w0BAQsFAAOCAQEAX1YfyL7VmUOuhS0q"
      + "j7Y3pEOVb2rd15YQIf7xZifCYKViKn/JShfNkPWXdZ+HZbBsCHtUkYFqQaAADdLqJityLRRlnq4ErRBvWH3KO9et/pIXKMZT"
      + "O/mmjdoar47JXHC73qME4EbnvWevAehiARQEZOJa7IxZXP0qbX4GtR8o/Fs8aK65z3NKYcVlUpzUyG02dV4CDBwJ6Eotjnjq"
      + "2Zk50LX0FrThOWuxaLG7GxLR45d0nfSrKc0FYu5HPZ2eXymir2xdrpQTYejzgKltkUN7gJrhdIMCyyQ792xjn8tjjvEbsqOv"
      + "hkspnfOwnNAr4LqG0ow/Ue9MnGTzHF3AcwzpcQ=="
  )

  /// One second after the delegated response's thisUpdate time.
  private static let currentTime = Date(timeIntervalSince1970: 1_785_830_931)

  /// A structurally complete certificate carrying a controlled KeyUsage.
  private static func certificate(keyUsage: Data?) -> Data {
    var extensions: [Data] = []
    if let keyUsage {
      extensions.append(
        DerEncoder.sequence([
          DerEncoder.objectIdentifier(SignOids.keyUsage),
          DerEncoder.octetString(keyUsage),
        ])
      )
    }
    var fields = [
      DerEncoder.integer(1),
      DerEncoder.sequence([]),
      DerEncoder.sequence([]),
      DerEncoder.sequence([]),
      DerEncoder.sequence([]),
      DerEncoder.sequence([]),
    ]
    if !extensions.isEmpty {
      fields.append(
        DerEncoder.tlv(
          DerValues.tagContext3Constructed,
          DerEncoder.sequence(extensions)
        )
      )
    }
    let tbs = DerEncoder.sequence(fields)
    return DerEncoder.sequence([
      tbs,
      DerEncoder.sequence([]),
      DerEncoder.tlv(DerValues.tagBitString, Data([0, 0])),
    ])
  }

  @Test
  internal func delegatedResponderWithEkuAndNoCheckIsAccepted() throws {
    let validity = try Fixture.validate(Self.responseWithNoCheck)

    #expect(validity.thisUpdate < Self.currentTime)
  }

  @Test
  internal func delegatedResponderWithoutNoCheckNeedsRevocationEvidence() {
    #expect(throws: OcspResponse.ValidationFailure.responderRevocationUnchecked) {
      _ = try Fixture.validate(Self.responseWithoutNoCheck)
    }
  }

  @Test
  internal func delegatedResponderWithoutOcspSigningEkuIsUnauthorized() {
    #expect(throws: OcspResponse.ValidationFailure.responderUnauthorized) {
      _ = try Fixture.validate(Self.responseWithoutOcspSigningEku)
    }
  }

  /// A present KeyUsage constrains the key even when the certificate also
  /// carries id-kp-OCSPSigning and a cryptographic signature verifies.
  @Test
  internal func delegatedResponderKeyUsageMustPermitDigitalSignature() throws {
    let digitalSignature = DerEncoder.tlv(
      DerValues.tagBitString,
      Data([0, UInt8(1) << (UInt8.bitWidth - 1)])
    )
    let keyEncipherment = DerEncoder.tlv(
      DerValues.tagBitString,
      Data([0, UInt8(1) << (UInt8.bitWidth - 3)])
    )

    #expect(
      try OcspResponse.delegatedResponderKeyUsagePermitsSigning(
        in: Self.certificate(keyUsage: nil)
      )
    )
    #expect(
      try OcspResponse.delegatedResponderKeyUsagePermitsSigning(
        in: Self.certificate(keyUsage: digitalSignature)
      )
    )
    #expect(
      try !OcspResponse.delegatedResponderKeyUsagePermitsSigning(
        in: Self.certificate(keyUsage: keyEncipherment)
      )
    )
  }
}
