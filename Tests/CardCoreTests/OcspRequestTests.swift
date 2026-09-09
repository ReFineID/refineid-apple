// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation
import Testing

/// Direct RFC 6960 and RFC 9654 request-encoding checks.
@Suite
internal struct OcspRequestTests {
  /// The client uses the current specification's recommended nonce size.
  @Test
  internal func nonceSizeIsThirtyTwoOctets() {
    #expect(OcspRequest.nonceByteCount == 32)
  }

  /// CertID hashes the exact issuer Name and public-key bits, preserves
  /// the serial INTEGER content, and wraps the nonce twice as specified.
  @Test
  internal func requestCarriesExactCertIdAndNonce() {
    let issuerName = Data("encoded issuer name".utf8)
    let issuerKey = Data("subject public key bits".utf8)
    let serial = WireHex.data("0080A1")
    let nonce = Data(repeating: 0x5A, count: OcspRequest.nonceByteCount)

    let request = OcspRequest.encoded(
      issuerName: issuerName,
      issuerKey: issuerKey,
      serial: serial,
      nonce: nonce
    )

    #expect(
      request.contains(
        DerEncoder.octetString(Data(Insecure.SHA1.hash(data: issuerName)))
      )
    )
    #expect(
      request.contains(
        DerEncoder.octetString(Data(Insecure.SHA1.hash(data: issuerKey)))
      )
    )
    #expect(request.contains(DerEncoder.tlv(0x02, serial)))
    #expect(
      request.contains(
        DerEncoder.octetString(DerEncoder.octetString(nonce))
      )
    )
  }
}
