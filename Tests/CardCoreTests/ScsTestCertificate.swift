// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation

/// Builds a minimal self-signed P-256 certificate for SCS tests: the
/// transaction flow verifies the relying service's JWS against a
/// certificate, so the tests mint one whose key they hold.
internal enum ScsTestCertificate {
  /// One freshly-generated certificate and its signing key.
  internal struct Material {
    internal let der: Data
    internal let key: P256.Signing.PrivateKey
  }

  private static let utf8StringTag: UInt8 = 0x0C
  private static let utcTimeTag: UInt8 = 0x17
  private static let bitStringTag: UInt8 = 0x03
  private static let explicitVersionTag: UInt8 = 0xA0
  private static let versionThreeValue = 2

  /// A certificate valid across a window that includes today.
  internal static func make() -> Material {
    make(notBefore: "200101000000Z", notAfter: "400101000000Z")
  }

  /// A certificate valid across the given UTCTime strings.
  internal static func make(notBefore: String, notAfter: String) -> Material {
    let key = P256.Signing.PrivateKey()
    let commonName = DerEncoder.sequence([
      DerEncoder.objectIdentifier("2.5.4.3"),
      DerEncoder.tlv(utf8StringTag, Data("scs-test".utf8)),
    ])
    let name = DerEncoder.sequence([DerEncoder.setOf([commonName])])
    let signatureAlgorithm = DerEncoder.sequence([
      DerEncoder.objectIdentifier("1.2.840.10045.4.3.2")
    ])
    let validity = DerEncoder.sequence([
      DerEncoder.tlv(utcTimeTag, Data(notBefore.utf8)),
      DerEncoder.tlv(utcTimeTag, Data(notAfter.utf8)),
    ])
    let tbs = DerEncoder.sequence([
      DerEncoder.tlv(explicitVersionTag, DerEncoder.integer(versionThreeValue)),
      DerEncoder.integer(1),
      signatureAlgorithm,
      name,
      validity,
      name,
      key.publicKey.derRepresentation,
    ])
    let signature = (try? key.signature(for: tbs))?.derRepresentation ?? Data()
    var signatureBits = Data([0x00])
    signatureBits.append(signature)
    let certificate = DerEncoder.sequence([
      tbs,
      signatureAlgorithm,
      DerEncoder.tlv(bitStringTag, signatureBits),
    ])
    return Material(der: certificate, key: key)
  }
}
