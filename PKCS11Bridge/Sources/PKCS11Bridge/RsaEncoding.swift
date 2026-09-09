// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation

/// RSA encoding translations between Security.framework and PKCS#11.
///
/// Security.framework hands out the PKCS#1 RSAPublicKey structure,
/// while PKCS#11 wants the modulus and public exponent as separate
/// attributes. CKM_RSA_PKCS takes a DigestInfo the caller has already
/// built, so signing splits it back into the digest and its algorithm,
/// which is what SecKeyCreateSignature accepts.
package enum RsaEncoding {
  /// A parsed PKCS#1 RSAPublicKey.
  package struct PublicKey {
    /// The modulus, leading zero removed, as CKA_MODULUS carries it.
    package let modulus: Data

    /// The public exponent, as CKA_PUBLIC_EXPONENT carries it.
    package let exponent: Data
  }

  /// A parsed DigestInfo: the digest and the algorithm that made it.
  package struct Digest {
    /// The bare digest, without the DigestInfo wrapper.
    package let value: Data

    /// The Security.framework algorithm signing this digest under
    /// PKCS#1 v1.5.
    package let algorithm: SecKeyAlgorithm
  }

  /// Signing algorithms by DigestInfo algorithm identifier.
  ///
  /// Keyed by the OID contents of the AlgorithmIdentifier. Named OID
  /// values come from DigestInfo.h in the CCryptoki target.
  private static let digestAlgorithms: [Data: SecKeyAlgorithm] = [
    oid(DigestOidSha1): .rsaSignatureDigestPKCS1v15SHA1,
    oid(DigestOidSha224): .rsaSignatureDigestPKCS1v15SHA224,
    oid(DigestOidSha256): .rsaSignatureDigestPKCS1v15SHA256,
    oid(DigestOidSha384): .rsaSignatureDigestPKCS1v15SHA384,
    oid(DigestOidSha512): .rsaSignatureDigestPKCS1v15SHA512,
  ]

  /// The bytes of a named OID value.
  private static func oid<Value>(_ value: Value) -> Data {
    withUnsafeBytes(of: value) { Data($0) }
  }

  /// Splits a PKCS#1 RSAPublicKey into its modulus and exponent.
  package static func publicKey(fromExternal external: Data) -> PublicKey? {
    var index = 0
    guard Asn1.tag(external, &index) == Asn1SequenceTag,
      let bodyLength = Asn1.length(external, &index),
      bodyLength == external.count - index,
      let modulus = Asn1.integer(external, &index),
      let exponent = Asn1.integer(external, &index),
      index == external.count
    else { return nil }
    return PublicKey(modulus: modulus, exponent: exponent)
  }

  /// Splits a DigestInfo into the digest and its signing algorithm.
  ///
  /// The structure is SEQUENCE { AlgorithmIdentifier, OCTET STRING },
  /// which CKM_RSA_PKCS callers such as OpenSSH build themselves.
  package static func digest(fromDigestInfo info: Data) -> Digest? {
    var index = 0
    guard Asn1.tag(info, &index) == Asn1SequenceTag,
      let bodyLength = Asn1.length(info, &index),
      bodyLength == info.count - index,
      Asn1.tag(info, &index) == Asn1SequenceTag,
      let algorithmLength = Asn1.length(info, &index)
    else { return nil }
    let algorithmEnd = index + algorithmLength
    guard Asn1.tag(info, &index) == Asn1ObjectIdentifierTag,
      let oidLength = Asn1.length(info, &index),
      index + oidLength <= info.count
    else { return nil }
    let oid = Data(info[index..<(index + oidLength)])
    index = algorithmEnd
    guard let algorithm = digestAlgorithms[oid],
      Asn1.tag(info, &index) == Asn1OctetStringTag,
      let digestLength = Asn1.length(info, &index),
      index + digestLength == info.count
    else { return nil }
    return Digest(value: Data(info[index...]), algorithm: algorithm)
  }
}
