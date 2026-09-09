// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// RFC 3161 request and response checks, independent of the network.
@Suite
internal struct RfcTimestampTests {
  /// Tags used only to assemble synthetic test messages.
  private enum Tag {
    static let null: UInt8 = 0x05
    static let generalizedTime: UInt8 = 0x18
    static let context0: UInt8 = 0xA0
  }

  private static let sha384 = "2.16.840.1.101.3.4.2.2"
  private static let sha256 = "2.16.840.1.101.3.4.2.1"
  private static let signedData = "1.2.840.113549.1.7.2"
  private static let tstInfo = "1.2.840.113549.1.9.16.1.4"
  private static let digest = Data(repeating: 0xA5, count: 48)
  private static let nonce = WireHex.data("0080A1B2C3D4")

  /// A complete synthetic TimeStampResp for structural checks.
  private static func response(
    imprintAlgorithm: String = Self.sha384,
    digest: Data = Self.digest,
    nonce: Data = Self.nonce,
    includeNonce: Bool = true,
    time: String = "20260804074633Z"
  ) -> Data {
    var fields = [
      DerEncoder.integer(1),
      DerEncoder.objectIdentifier("1.2.3.4"),
      DerEncoder.sequence([
        DerEncoder.sequence([
          DerEncoder.objectIdentifier(imprintAlgorithm),
          DerEncoder.tlv(Tag.null, Data()),
        ]),
        DerEncoder.octetString(digest),
      ]),
      DerEncoder.integer(7),
      DerEncoder.tlv(Tag.generalizedTime, Data(time.utf8)),
    ]
    if includeNonce {
      fields.append(DerEncoder.unsignedInteger(nonce))
    }
    let information = DerEncoder.sequence(fields)
    let encapsulated = DerEncoder.sequence([
      DerEncoder.objectIdentifier(Self.tstInfo),
      DerEncoder.tlv(
        Tag.context0, DerEncoder.octetString(information)
      ),
    ])
    let signed = DerEncoder.sequence([
      DerEncoder.integer(3),
      DerEncoder.setOf([
        DerEncoder.sequence([DerEncoder.objectIdentifier(imprintAlgorithm)])
      ]),
      encapsulated,
      DerEncoder.setOf([]),
    ])
    let token = DerEncoder.sequence([
      DerEncoder.objectIdentifier(Self.signedData),
      DerEncoder.tlv(Tag.context0, signed),
    ])
    return DerEncoder.sequence([
      DerEncoder.sequence([DerEncoder.integer(0)]), token,
    ])
  }

  @Test
  internal func requestCarriesTheDigestNonceAndCertificateRequest() {
    let request = RfcTimestamp.request(
      digest: Self.digest, nonceBytes: Self.nonce
    )
    #expect(request.contains(Self.digest))
    #expect(request.contains(DerEncoder.unsignedInteger(Self.nonce)))
    #expect(request.contains(DerEncoder.objectIdentifier(Self.sha384)))
    #expect(request.suffix(3) == WireHex.data("0101FF"))
  }

  @Test
  internal func matchingResponseReturnsItsTokenVerbatim() throws {
    let response = Self.response()
    let token = try RfcTimestamp.token(
      fromResponse: response, digest: Self.digest, nonceBytes: Self.nonce
    )
    #expect(response.contains(token))
  }

  @Test
  internal func messageImprintAlgorithmMustMatchTheRequest() {
    let response = Self.response(imprintAlgorithm: Self.sha256)
    #expect(throws: RfcTimestamp.TokenFailure.imprintAlgorithmMismatch) {
      _ = try RfcTimestamp.token(
        fromResponse: response,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
  }

  @Test
  internal func messageImprintBytesMustMatchTheRequest() {
    let response = Self.response(digest: Data(repeating: 0x5A, count: 48))
    #expect(throws: RfcTimestamp.TokenFailure.imprintMismatch) {
      _ = try RfcTimestamp.token(
        fromResponse: response,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
  }

  /// A SHA-384 identifier cannot legitimize another digest size.
  @Test
  internal func sha384ImprintMustHaveTheSha384Length() {
    let short = Data(repeating: 0xA5, count: 32)
    let response = Self.response(digest: short)
    #expect(throws: RfcTimestamp.TokenFailure.malformed) {
      _ = try RfcTimestamp.token(
        fromResponse: response,
        digest: short,
        nonceBytes: Self.nonce
      )
    }
  }

  @Test
  internal func nonceMustBePresentAndEqual() {
    let absent = Self.response(includeNonce: false)
    #expect(throws: RfcTimestamp.TokenFailure.nonceMismatch) {
      _ = try RfcTimestamp.token(
        fromResponse: absent,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
    let different = Self.response(nonce: WireHex.data("010203"))
    #expect(throws: RfcTimestamp.TokenFailure.nonceMismatch) {
      _ = try RfcTimestamp.token(
        fromResponse: different,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
  }

  @Test
  internal func generationTimeIsParsedAsUtc() throws {
    let token = try RfcTimestamp.token(
      fromResponse: Self.response(time: "20260804074633.125Z"),
      digest: Self.digest,
      nonceBytes: Self.nonce
    )
    let expected = Date(timeIntervalSince1970: 1_785_829_593.125)
    #expect(try RfcTimestamp.generationTime(in: token) == expected)
  }

  @Test
  internal func malformedGenerationTimeAndTrailingBytesAreRejected() {
    let malformed = Self.response(time: "20261304074633Z")
    #expect(throws: RfcTimestamp.TokenFailure.malformed) {
      _ = try RfcTimestamp.token(
        fromResponse: malformed,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
    let oversizedFraction = Self.response(
      time: "20260804074633." + String(repeating: "9", count: 128) + "Z"
    )
    #expect(throws: RfcTimestamp.TokenFailure.malformed) {
      _ = try RfcTimestamp.token(
        fromResponse: oversizedFraction,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
    var trailing = Self.response()
    trailing.append(0)
    #expect(throws: RfcTimestamp.TokenFailure.malformed) {
      _ = try RfcTimestamp.token(
        fromResponse: trailing,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
  }

  @Test
  internal func rejectedStatusIsNotAUsableToken() {
    let rejected = DerEncoder.sequence([
      DerEncoder.sequence([DerEncoder.integer(2)])
    ])
    #expect(throws: RfcTimestamp.TokenFailure.rejected(status: 2)) {
      _ = try RfcTimestamp.token(
        fromResponse: rejected,
        digest: Self.digest,
        nonceBytes: Self.nonce
      )
    }
  }
}
