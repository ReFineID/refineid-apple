// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

extension CertificateRevocationListFixtures.SignatureKind {
  /// ASN.1 signature algorithm object identifier.
  internal var algorithmOid: String {
    switch self {
    case .ecdsaSha256:
      "1.2.840.10045.4.3.2"

    case .ecdsaSha384:
      "1.2.840.10045.4.3.3"

    case .ecdsaSha512:
      "1.2.840.10045.4.3.4"

    case .rsaSha256:
      "1.2.840.113549.1.1.11"

    case .rsaSha384:
      "1.2.840.113549.1.1.12"

    case .rsaSha512:
      "1.2.840.113549.1.1.13"
    }
  }

  /// Named elliptic curve object identifier, or nil for RSA.
  internal var curveOid: String? {
    switch self {
    case .ecdsaSha256:
      "1.2.840.10045.3.1.7"

    case .ecdsaSha384:
      "1.3.132.0.34"

    case .ecdsaSha512:
      "1.3.132.0.35"

    case .rsaSha256, .rsaSha384, .rsaSha512:
      nil
    }
  }
}
