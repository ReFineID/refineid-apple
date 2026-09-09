// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

/// Direct issuer-KeyUsage edge cases for complete, issuer-signed CRLs.
@Suite
internal struct CertificateRevocationListKeyUsageTests {
  /// Declared unused KeyUsage bits must be zero and cannot authorize cRLSign.
  @Test
  internal func issuerWithNonzeroUnusedKeyUsageBitsIsRejected() throws {
    let material = try CertificateRevocationListFixtures.make(
      kind: .ecdsaSha256,
      options: .standard,
      targetSignedByWrongKey: false,
      issuerKeyUsage: .malformedUnusedBits
    )

    #expect(
      throws: CertificateRevocationList.ValidationFailure.certificateUnparseable
    ) {
      _ = try CertificateRevocationList.validate(
        crl: material.crl,
        certificate: material.certificate,
        issuerCertificate: material.issuerCertificate,
        currentTime: material.currentTime
      )
    }
  }
}
