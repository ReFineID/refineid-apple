// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The self-signed localhost server certificate the SCS presents at
/// `https://127.0.0.1:53952` (DVV SCS specification v1.3 §2.3).
///
/// The specification names the attributes the browser checks before
/// it will talk to the local service: CN `127.0.0.1`, subjectAltName
/// with both the loopback address and `localhost`, KeyUsage
/// digitalSignature and keyEncipherment, and extended key usage
/// serverAuth. Signing stays a caller-supplied closure so the key
/// can live wherever the platform keeps it.
public enum ScsLocalhostCertificate {
  /// The certificate's common name, which the specification fixes at
  /// the loopback address (v1.3 §2.3).
  ///
  /// Public because it is also how the certificate is found again:
  /// the keychain derives a certificate's label from its subject, so
  /// this name - not a label chosen at store time - is the reliable
  /// handle on it.
  public static let commonName = "127.0.0.1"

  /// The certificate's one subject and issuer name.
  private static var name: Data {
    let attribute = DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.commonName),
      DerEncoder.tlv(DerValues.tagUtf8String, Data(Self.commonName.utf8)),
    ])
    return DerEncoder.sequence([DerEncoder.setOf([attribute])])
  }

  /// ecdsa-with-SHA256, the signature this builder expects from its
  /// signing closure.
  private static var signatureAlgorithm: Data {
    DerEncoder.sequence([DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256)])
  }

  /// Universal tag: UTCTime (RFC 5280 section 4.1.2.5.1).
  private static var utcTimeTag: UInt8 {
    DerValues.tagGeneralizedTime - UInt8(MemoryLayout<UInt8>.size)
  }

  /// Wraps a P-256 public key's X9.63 representation as a DER
  /// SubjectPublicKeyInfo.
  public static func subjectPublicKeyInfo(fromX963 representation: Data) -> Data {
    let algorithm = DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.ecPublicKey),
      DerEncoder.objectIdentifier(SignOids.prime256v1),
    ])
    var bits = Data([DerValues.bitStringNoUnusedBits])
    bits.append(representation)
    return DerEncoder.sequence([
      algorithm,
      DerEncoder.tlv(DerValues.tagBitString, bits),
    ])
  }

  /// Builds and signs the certificate.
  ///
  /// `sign` receives the DER TBSCertificate and must answer an
  /// ecdsa-with-SHA256 signature in X9.62 DER form.
  public static func make(
    subjectPublicKeyInfo: Data,
    serialNumber: Data,
    from notBefore: Date,
    signedBy sign: (Data) throws -> Data
  ) rethrows -> Data {
    let tbs = tbsCertificate(
      subjectPublicKeyInfo: subjectPublicKeyInfo,
      serialNumber: serialNumber,
      notBefore: notBefore
    )
    let signature = try sign(tbs)
    var bits = Data([DerValues.bitStringNoUnusedBits])
    bits.append(signature)
    return DerEncoder.sequence([
      tbs,
      signatureAlgorithm,
      DerEncoder.tlv(DerValues.tagBitString, bits),
    ])
  }

  /// The to-be-signed body: version 3, the fixed names, the §2.3
  /// extension set.
  private static func tbsCertificate(
    subjectPublicKeyInfo: Data,
    serialNumber: Data,
    notBefore: Date
  ) -> Data {
    let calendar = Calendar(identifier: .gregorian)
    let notAfter =
      calendar.date(
        byAdding: .year,
        value: ScsValues.certificateValidityYears,
        to: notBefore
      ) ?? notBefore
    let validity = DerEncoder.sequence([
      utcTime(notBefore),
      utcTime(notAfter),
    ])
    let versionThree = 2
    return DerEncoder.sequence([
      DerEncoder.tlv(DerValues.tagContext0Constructed, DerEncoder.integer(versionThree)),
      DerEncoder.unsignedInteger(serialNumber),
      signatureAlgorithm,
      name,
      validity,
      name,
      subjectPublicKeyInfo,
      DerEncoder.tlv(DerValues.tagContext3Constructed, extensions()),
    ])
  }

  /// The §2.3 extension set: CA basic constraints (so a browser can
  /// trust the self-signed leaf as its own root), the key usages,
  /// serverAuth, and the loopback subject names.
  private static func extensions() -> Data {
    let basicConstraints = extensionRecord(
      oid: SignOids.basicConstraints,
      critical: true,
      value: DerEncoder.sequence([DerEncoder.booleanTrue(), DerEncoder.integer(0)])
    )
    let keyUsage = extensionRecord(
      oid: SignOids.keyUsage,
      critical: true,
      value: DerEncoder.tlv(
        DerValues.tagBitString,
        Data([ScsValues.serverKeyUsageUnusedBits, ScsValues.serverKeyUsageBits])
      )
    )
    let extendedKeyUsage = extensionRecord(
      oid: SignOids.extendedKeyUsage,
      critical: false,
      value: DerEncoder.sequence([
        DerEncoder.objectIdentifier(SignOids.serverAuthentication)
      ])
    )
    let alternativeNames = extensionRecord(
      oid: SignOids.subjectAltName,
      critical: false,
      value: DerEncoder.sequence([
        DerEncoder.tlv(DerValues.tagContext2Primitive, Data("localhost".utf8)),
        DerEncoder.tlv(DerValues.tagContext7Primitive, Data(ScsValues.loopbackAddress)),
      ])
    )
    return DerEncoder.sequence([
      basicConstraints,
      keyUsage,
      extendedKeyUsage,
      alternativeNames,
    ])
  }

  /// One Extension record: identifier, criticality, wrapped value.
  private static func extensionRecord(
    oid: String,
    critical: Bool,
    value: Data
  ) -> Data {
    var elements = [DerEncoder.objectIdentifier(oid)]
    if critical {
      elements.append(DerEncoder.booleanTrue())
    }
    elements.append(DerEncoder.octetString(value))
    return DerEncoder.sequence(elements)
  }

  /// RFC 5280 UTCTime for `date`, whole seconds, Zulu.
  private static func utcTime(_ date: Date) -> Data {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyMMddHHmmss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return DerEncoder.tlv(Self.utcTimeTag, Data(formatter.string(from: date).utf8))
  }
}
