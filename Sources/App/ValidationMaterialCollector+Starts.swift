// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// Strict certificate-path ordering for validation-material collection.
extension ValidationMaterialCollector {
  /// Orders TSA checks before any document-signer fallback can apply.
  internal static func orderedChainStarts(
    signerCertificate: Data,
    timestampTokens: [TimestampTokenVerifier.VerifiedToken],
    signerTrustCertificates: Set<Data>,
    evidenceTime: Date
  ) -> [ChainStart] {
    var starts = timestampTokens.map { token in
      ChainStart(
        certificate: token.signerCertificate,
        role: .timestampAuthority,
        referenceDate: token.generatedAt,
        trustedCertificates: [token.trustedCertificate]
      )
    }
    starts.append(
      ChainStart(
        certificate: signerCertificate,
        role: .documentSigner,
        referenceDate: timestampTokens.first?.generatedAt ?? evidenceTime,
        trustedCertificates: signerTrustCertificates
      )
    )
    return starts
  }
}
