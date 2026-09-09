// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A certificate the card publishes, and everywhere it may live.
///
/// Directory placement follows FINEID S4-1 (citizen cards) and FINEID
/// S4-2 v4.0 (organization cards). Where the generations differ, a slot
/// lists both homes, citizen first, and the reader tries them in order:
/// the card is asked, not assumed, because nothing before the SELECT
/// answer distinguishes the layouts.
public enum CertificateSlot: Equatable, Sendable, CaseIterable {
  /// The client authentication leaf Safari uses: EF.4331, directly
  /// under the PKCS#15 application on both generations (S4-1;
  /// S4-2 v4.0 §4.6.5).
  case authentication

  /// The issuing intermediate CA that chains the authentication leaf
  /// upward, under the main file: EF.4336 on the citizen card,
  /// EF.4333 on the organization card (S4-2 v4.0 §4.6.6).
  case issuing

  /// The qualified-signature leaf, whose key PIN2 gates: EF.4332,
  /// directly under the PKCS#15 application on the citizen card, under
  /// DF.ESIGN on the organization card (S4-2 v4.0 §4.6.22).
  case qualifiedSignature

  /// The on-card root CA: EF.4334, under the main file on both
  /// generations (S4-2 v4.0 §4.6.7).
  case root

  /// The second authentication leaf: EF.4333.
  ///
  /// Filed beside its first, so it is looked for in the same two homes
  /// the qualified leaf has: under the PKCS#15 application, and under
  /// the signature directory where a card keeps it there instead.
  ///
  /// Dual-algorithm cards carry a second key pair per PIN. Which
  /// algorithm sits in which slot is not fixed, so the caller reads the
  /// certificate and takes the algorithm from its public key.
  case secondAuthentication

  /// The second qualified-signature leaf: EF.4335, the counterpart to
  /// EF.4332 and looked for in the same two homes.
  case secondQualifiedSignature

  /// One place a certificate can live: the directory to make current,
  /// then the elementary file to read there.
  public struct Location: Equatable, Sendable {
    /// The directory the reader navigates to first.
    public let directory: CertificateDirectory

    /// The elementary file holding the certificate.
    public let file: FileIdentifier
  }

  /// Everywhere this slot's certificate is documented to live, in the
  /// order to try.
  public var locations: [Location] {
    switch self {
    case .authentication:
      [Location(directory: .pkcs15Application, file: .authCertificate)]

    case .qualifiedSignature:
      [
        Location(directory: .pkcs15Application, file: .signatureCertificate),
        Location(directory: .esignApplication, file: .signatureCertificate),
        Location(directory: .pkcs15Application, file: .secondSignatureCertificate),
        Location(directory: .esignApplication, file: .secondSignatureCertificate),
      ]

    case .secondAuthentication:
      [
        Location(directory: .pkcs15Application, file: .secondAuthCertificate),
        Location(directory: .esignApplication, file: .secondAuthCertificate),
      ]

    case .secondQualifiedSignature:
      [
        Location(directory: .pkcs15Application, file: .secondSignatureCertificate),
        Location(directory: .esignApplication, file: .secondSignatureCertificate),
      ]

    case .issuing:
      [
        Location(directory: .mainFile, file: .issuingCertificate),
        Location(directory: .mainFile, file: .organizationIssuingCertificate),
      ]

    case .root:
      [Location(directory: .mainFile, file: .rootCertificate)]
    }
  }
}
