// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// Definitive non-good OCSP statuses must be authenticated before use.
@Suite
internal struct OcspStatusTests {
  /// Fixture decoding that keeps checked-in DER readable in source.
  private enum Fixture {
    /// Decodes an invariant base64 fixture without a forced unwrap.
    static func data(_ encoded: String) -> Data {
      Data(base64Encoded: encoded) ?? Data()
    }
  }

  /// A correctly signed direct-issuer response reporting the leaf revoked.
  private static let revokedResponse = Fixture.data(
    "MIICGwoBAKCCAhQwggIQBgkrBgEFBQcwAQEEggIBMIIB/TCB5qEiMCAxHjAcBgNVBAMMFVJlRmluZUlEIE9DU1AgVGVzdCBD"
      + "QRgPMjAyNjA4MDQwODExNDVaMIGJMIGGME0wCQYFKw4DAhoFAAQUbxOaojSmpa7Q0ITX8H99z4O/6O0EFC5KkvLIdNZZZvn3"
      + "Indr84LPW7PKAhQdj7qaW4e2abvc54FdTi0m/rKd5qERGA8yMDI2MDgwNDA4MDAwMFoYDzIwMjYwODA0MDgxMTQ1WqARGA8y"
      + "MDI2MDkwMzA4MTE0NVqhIzAhMB8GCSsGAQUFBzABAgQSBBC0cUHhoVNQXuNqpYUk7QUKMA0GCSqGSIb3DQEBCwUAA4IBAQA4"
      + "oBb9dDzTCBHWVUSjquX8IwFzZw5ZJGdcNFDuw2ap2EOwUT7PyeV+iwQSJZib/jUCG9Ial0Xhq6TwS1+xtsZHE5W6u8JZAcW4"
      + "t3pH/V3ueSgAtVGC6x9K5eRUeo8Mw+idsoXQlBLC4r4Y9f/vj4+iOdqFujaIoijtpv3rJQNXOll/F0MunJieUtM2idI9nkEa"
      + "Yvyd9cYLkm8047Cx1ez4eRBoNbMUyUA1uV9g8V93RTr/26/jw+Ua8LhiVf0ltzp7fByNAIzmpUrOwp7O+jzvxEKwQA8zwqRw"
      + "6oK9EYe7waGZIQmCJiAYkezc9djvyLtDrvsjjA606KrOnH9mF6IE"
  )

  /// A certificate not present in the responder's status database.
  private static let unknownCertificate = Fixture.data(
    "MIIDFTCCAf2gAwIBAgIUHY+6mluHtmm73OeBXU4tJv6ynekwDQYJKoZIhvcNAQELBQAwIDEeMBwGA1UEAwwVUmVGaW5lSUQg"
      + "T0NTUCBUZXN0IENBMB4XDTI2MDgwNDA4MTE1OVoXDTI3MDgwNDA4MTE1OVowJTEjMCEGA1UEAwwaUmVGaW5lSUQgT0NTUCBV"
      + "bmtub3duIExlYWYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDSp5VXyk5O5qT1CBzESV1zZtrAcI0Ipxg7v5W7"
      + "6MhHylpzxJbOA7Nrfew56lG4g1y1TjmCuF6vMAmdR7GiMAmmUIUv7yimQ10pz/BRyfBj7Ue/G4YxNlyexmQXhOt6kTZE+dUB"
      + "HWHg2ZcdXXRqO58MWSEY4hP6ONh20Uz29gpM6ewC1h+4CgP//b5ZDzsmS/YuP6Wx/5+zCJ6H1DDHQur0FqHDYxdJZQR+HlvB"
      + "8vrMYzseS7urNC97OMi8Lq2TuErIRqH3I/otv4SqruaPH1RRYZjJymvuIrKt/bKQda2zGIBzttkeYC3frMcpVXogcy+7Mi2F"
      + "GTlw4m50WGtRTruxAgMBAAGjQjBAMB0GA1UdDgQWBBTy4g7S+CuT5S1wvkZijO/DVryYeTAfBgNVHSMEGDAWgBQuSpLyyHTW"
      + "WWb59yJ3a/OCz1uzyjANBgkqhkiG9w0BAQsFAAOCAQEAi3IgVzov5Mtgdz94Yo6RMkaMTv9c2K3CGslQscupqueXUondBV3W"
      + "+kIu04GBKpy5iylW4e1N0LYJB3rP3C0yISbOBPeUk1iMbtjwExWmvQEkwJdyJPQD+2J7EEsbRZIulEJnnal79P039UHCEsPE"
      + "zNsaANHIxfFF9VV0oWedu+6koqH74tJGZ8QoZItyvamkiv653E8wq18GWsCKqDvP1D0wW3gDXcNrMx3HYs5h3REDNxTnVW1X"
      + "EPkYJrTHkwnD8PVjaA57VoIHJ+hTEKgQVnDuRd6y+QqgvrtLQV/R9ePtskLhFnLZyE+/qYGQn51Iu0JsChW7T/2MYUIWyekL"
      + "Qg=="
  )

  /// A correctly signed direct-issuer response reporting that certificate unknown.
  private static let unknownResponse = Fixture.data(
    "MIIB4woBAKCCAdwwggHYBgkrBgEFBQcwAQEEggHJMIIBxTCBrqEiMCAxHjAcBgNVBAMMFVJlRmluZUlEIE9DU1AgVGVzdCBD"
      + "QRgPMjAyNjA4MDQwODExNTlaMHcwdTBNMAkGBSsOAwIaBQAEFG8TmqI0pqWu0NCE1/B/fc+Dv+jtBBQuSpLyyHTWWWb59yJ3"
      + "a/OCz1uzygIUHY+6mluHtmm73OeBXU4tJv6ynemCABgPMjAyNjA4MDQwODExNTlaoBEYDzIwMjYwOTAzMDgxMTU5WjANBgkq"
      + "hkiG9w0BAQsFAAOCAQEAM43vUutnjqNZkMG9feDTu8zGGwbry3pIqUFIqjtfuxeVRk5SC1NxpYrs2EnbhtD+X//UMQfu+LRh"
      + "+cwuTqq+U7WnWrIpp89usC2qM85NjclNM3zdOHCrytFTxm7rZ8eDx3rIy+4Y1iyCbxcko2a/MdNm/NP00Pgdv+8pr1unEzaY"
      + "kU7gyDRe25W3VOsHJItMrqsl/zm8tn5ZSjEQE7xCAtBSI56c6c283oLVu0OL9z8zl0r5ojZeKlgj9cwzJRiS38UIho02tpNt"
      + "s49fL/5ylMV0lL0Ud0wMf1qUiM6UVrl6XPSr0sfLPkviA1OriDZmmtgtwujK43Oarz3EjpQENA=="
  )

  /// One second after the revocation response's thisUpdate time.
  private static let revokedResponseTime = Date(timeIntervalSince1970: 1_785_831_106)

  /// One second after the unknown response's thisUpdate time.
  private static let unknownResponseTime = Date(timeIntervalSince1970: 1_785_831_120)

  @Test
  internal func signedRevocationStatusIsReported() {
    #expect(
      CertificateIssuer.cryptographicallyDirectlyIssued(
        OcspResponseTests.certificate,
        by: OcspResponseTests.issuerCertificate,
        at: Self.revokedResponseTime
      )
    )
    #expect(throws: OcspResponse.ValidationFailure.revoked) {
      _ = try OcspResponse.validate(
        response: Self.revokedResponse,
        certificate: OcspResponseTests.certificate,
        issuerCertificate: OcspResponseTests.issuerCertificate,
        nonce: OcspResponseTests.nonce,
        currentTime: Self.revokedResponseTime
      )
    }
  }

  @Test
  internal func signedUnknownStatusIsReported() {
    #expect(throws: OcspResponse.ValidationFailure.unknown) {
      _ = try OcspResponse.validate(
        response: Self.unknownResponse,
        certificate: Self.unknownCertificate,
        issuerCertificate: OcspResponseTests.issuerCertificate,
        nonce: OcspResponseTests.nonce,
        currentTime: Self.unknownResponseTime
      )
    }
  }
}
