// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Security

/// Certificate-path construction for validation-material collection.
extension ValidationMaterialCollector {
  /// Finds an embedded or AIA issuer and verifies its certificate signature.
  internal static func issuer(
    of subject: Data,
    facts: CertificateFacts,
    at referenceDate: Date,
    collection: inout Collection,
    dependencies: Dependencies
  ) async throws -> Data {
    if let embedded = collection.candidates.first(where: { candidate in
      candidate != subject
        && CertificateIssuer.isDirectlyIssued(
          subject, by: candidate, at: referenceDate
        )
    }) {
      return embedded
    }
    for address in Self.boundedCertificateAddresses(
      facts.issuerCertificateUrls
    ) {
      guard
        let body = try? await dependencies.get(address, false),
        let candidate = Self.certificate(from: body),
        CertificateIssuer.isDirectlyIssued(
          subject, by: candidate, at: referenceDate
        )
      else { continue }
      collection.addCandidate(candidate)
      return candidate
    }
    throw Failure.issuerUnavailable
  }

  /// PEM unwrapped to one DER certificate, or DER unchanged.
  private static func certificate(from body: Data) -> Data? {
    if SecCertificateCreateWithData(nil, body as CFData) != nil {
      return body
    }
    guard let text = String(data: body, encoding: .ascii) else { return nil }
    let base64 =
      text
      .split(whereSeparator: \.isNewline)
      .filter { !$0.hasPrefix("-----") }
      .joined()
    guard
      let decoded = Data(base64Encoded: String(base64)),
      SecCertificateCreateWithData(nil, decoded as CFData) != nil
    else { return nil }
    return decoded
  }
}
