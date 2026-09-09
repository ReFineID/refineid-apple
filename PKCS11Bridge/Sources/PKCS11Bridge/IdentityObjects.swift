// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import Security

/// Builds the PKCS#11 objects one token identity publishes.
///
/// Each identity becomes a certificate, a public key, and a private
/// key sharing one CKA_ID. What distinguishes them beyond their class
/// is the cryptosystem: an EC key carries its curve and point, an RSA
/// key its modulus and exponent, and each signs with its own mechanism
/// and signature length.
internal enum IdentityObjects {
  /// One object record before handle assignment.
  internal struct Blueprint {
    /// CKO_CERTIFICATE, CKO_PUBLIC_KEY, or CKO_PRIVATE_KEY.
    internal let objectClass: CK_OBJECT_CLASS

    /// Precomputed attribute values.
    internal let attributes: [CK_ATTRIBUTE_TYPE: Data]

    /// EC field width in bytes; zero on the certificate.
    internal let fieldWidth: Int

    /// The signing key on the private-key object.
    internal let privateKey: SecKey?
  }

  /// What one identity's public key says about its cryptosystem: the
  /// key attributes shared by its objects, and the sizes the signing
  /// path needs.
  internal struct KeyShape {
    /// The identity's cryptosystem.
    internal let kind: ModuleRegistry.KeyKind

    /// CKA_KEY_TYPE and the cryptosystem's own key attributes.
    internal let attributes: [CK_ATTRIBUTE_TYPE: Data]

    /// EC field width in bytes; zero for RSA.
    internal let fieldWidth: Int

    /// The signature this key produces, in bytes.
    internal let signatureLength: Int
  }

  /// An EC signature concatenates two field-width halves.
  private static let ecSignatureHalves = 2

  /// Bits per byte, for reporting CKA_MODULUS_BITS.
  private static let bitsPerByte = 8

  /// The certificate, public-key, and private-key objects one
  /// identity publishes.
  internal static func blueprints(
    common: [CK_ATTRIBUTE_TYPE: Data],
    certificate: SecCertificate,
    shape: KeyShape,
    privateKey: SecKey
  ) -> [Blueprint] {
    let keyCommon = common.merging(shape.attributes) { _, new in new }
    return [
      Blueprint(
        objectClass: CKO_CERTIFICATE,
        attributes: certificateAttributes(common: common, certificate: certificate),
        fieldWidth: 0,
        privateKey: nil),
      Blueprint(
        objectClass: CKO_PUBLIC_KEY,
        attributes: keyCommon.merging([
          CKA_CLASS: word(CKO_PUBLIC_KEY),
          CKA_VERIFY: flag(true),
        ]) { _, new in new },
        fieldWidth: shape.fieldWidth,
        privateKey: nil),
      Blueprint(
        objectClass: CKO_PRIVATE_KEY,
        attributes: keyCommon.merging([
          CKA_CLASS: word(CKO_PRIVATE_KEY),
          CKA_SIGN: flag(true),
          CKA_SENSITIVE: flag(true),
          // What the card is: a key that was generated on it and can
          // never come off it. Spec section 5.7.5 lets a module answer
          // CKR_ATTRIBUTE_TYPE_INVALID for an attribute it does not
          // keep, and this one did, but SunPKCS11 reads CKA_EXTRACTABLE
          // for every private key it opens and treats that answer as
          // fatal -- so Java could list the key and never use it.
          CKA_EXTRACTABLE: flag(false),
          CKA_NEVER_EXTRACTABLE: flag(true),
          CKA_ALWAYS_SENSITIVE: flag(true),
          CKA_LOCAL: flag(true),
          CKA_ALWAYS_AUTHENTICATE: flag(false),
        ]) { _, new in new },
        fieldWidth: shape.fieldWidth,
        privateKey: privateKey),
    ]
  }

  /// Reads the cryptosystem and key attributes from a public key, or
  /// nil when it is neither a supported EC curve nor RSA.
  internal static func keyShape(_ publicKey: SecKey) -> KeyShape? {
    guard let external = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
    else { return nil }
    if let width = EcEncoding.fieldWidth(uncompressedPoint: external),
      let parameters = EcEncoding.parameters(fieldWidth: width)
    {
      return KeyShape(
        kind: .elliptic,
        attributes: [
          CKA_KEY_TYPE: word(CKK_EC),
          CKA_EC_PARAMS: parameters,
          CKA_EC_POINT: EcEncoding.wrappedPoint(external),
        ],
        fieldWidth: width,
        signatureLength: ecSignatureHalves * width)
    }
    guard let rsa = RsaEncoding.publicKey(fromExternal: external) else { return nil }
    return KeyShape(
      kind: .rsa,
      attributes: [
        CKA_KEY_TYPE: word(CKK_RSA),
        CKA_MODULUS: rsa.modulus,
        CKA_MODULUS_BITS: word(CK_ULONG(rsa.modulus.count * bitsPerByte)),
        CKA_PUBLIC_EXPONENT: rsa.exponent,
      ],
      fieldWidth: 0,
      signatureLength: rsa.modulus.count)
  }

  /// Certificate-object attributes.
  internal static func certificateAttributes(
    common: [CK_ATTRIBUTE_TYPE: Data], certificate: SecCertificate
  ) -> [CK_ATTRIBUTE_TYPE: Data] {
    var values = common.merging([
      CKA_CLASS: word(CKO_CERTIFICATE),
      CKA_CERTIFICATE_TYPE: word(CKC_X_509),
      CKA_VALUE: SecCertificateCopyData(certificate) as Data,
    ]) { _, new in new }
    if let subject = SecCertificateCopyNormalizedSubjectSequence(certificate) {
      values[CKA_SUBJECT] = subject as Data
    }
    if let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate) {
      values[CKA_ISSUER] = issuer as Data
    }
    if let serial = SecCertificateCopySerialNumberData(certificate, nil) {
      // PKCS#11 defines CKA_SERIAL_NUMBER as the DER encoding of the
      // serial-number INTEGER; Security.framework hands out only its
      // content octets, so the tag and length go back on here.
      values[CKA_SERIAL_NUMBER] = Asn1.integerEncoded(content: serial as Data)
    }
    return values
  }

  /// A CK_ULONG attribute value in the process's native layout.
  internal static func word(_ value: CK_ULONG) -> Data {
    withUnsafeBytes(of: value) { Data($0) }
  }

  /// A CK_BBOOL attribute value.
  internal static func flag(_ value: Bool) -> Data {
    Data([value ? CK_TRUE : CK_FALSE])
  }
}
