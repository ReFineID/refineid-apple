// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Finds a bundled issuing certificate for a card leaf.
///
/// Some older FINEID cards expose their authentication leaf but not the
/// issuing CA file. CryptoTokenKit can still sign with that leaf, but a
/// browser cannot send a complete client-certificate chain. The app and
/// token extension therefore bundle public FINEID intermediates and
/// select one only when its normalized subject exactly equals the leaf's
/// normalized issuer.
public enum BundledIssuerCertificate {
  /// Resource prefix reserved for public FINEID issuing certificates.
  private static let resourcePrefix = "fineid-intermediate-"

  /// Returns the matching intermediate in DER form.
  public static func der(
    matching leafDER: Data,
    in bundle: Bundle = .main
  ) -> Data? {
    if let cached = TrustRootsCache.shared.der(matching: leafDER) {
      return cached
    }
    guard
      let leaf = SecCertificateCreateWithData(nil, leafDER as CFData),
      let issuer = SecCertificateCopyNormalizedIssuerSequence(leaf) as Data?
    else {
      return nil
    }
    return candidates(in: bundle).first { candidateDER in
      guard
        let candidate = SecCertificateCreateWithData(nil, candidateDER as CFData),
        let subject = SecCertificateCopyNormalizedSubjectSequence(candidate) as Data?
      else {
        return false
      }
      return subject == issuer
    }
  }

  /// Loads every matching DER or PEM resource from a bundle.
  private static func candidates(in bundle: Bundle) -> [Data] {
    let derURLs =
      bundle.urls(forResourcesWithExtension: "der", subdirectory: nil) ?? []
    let pemURLs =
      bundle.urls(forResourcesWithExtension: "pem", subdirectory: nil) ?? []
    return (derURLs + pemURLs)
      .filter { $0.lastPathComponent.hasPrefix(Self.resourcePrefix) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
      .compactMap(Self.readCertificate)
  }

  /// Reads a DER resource directly or strips one PEM envelope.
  private static func readCertificate(from url: URL) -> Data? {
    guard let bytes = try? Data(contentsOf: url) else { return nil }
    guard url.pathExtension.lowercased() == "pem" else { return bytes }
    guard let text = String(data: bytes, encoding: .ascii) else { return nil }
    let base64 =
      text
      .split(whereSeparator: \.isNewline)
      .filter { !$0.hasPrefix("-----") }
      .joined()
    return Data(base64Encoded: base64)
  }
}
