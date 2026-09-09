// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation

/// EC encoding translations between Security.framework and PKCS#11.
///
/// Security.framework hands out uncompressed SEC 1 points and X9.62 DER
/// signatures; PKCS#11 wants the named-curve OID in CKA_EC_PARAMS, the
/// point wrapped in a DER OCTET STRING in CKA_EC_POINT, and CKM_ECDSA
/// signatures as the raw r||s concatenation. Named protocol values come
/// from EcEncoding.h in the CCryptoki target.
package enum EcEncoding {
  /// An uncompressed point carries two coordinates; a raw signature
  /// carries two halves.
  private static let elementCount = 2

  /// DER-encoded named-curve OID for a field width in bytes, or nil
  /// for an unsupported curve.
  package static func parameters(fieldWidth: Int) -> Data? {
    switch CK_ULONG(fieldWidth) {
    case EcFieldBytesP256:
      return withUnsafeBytes(of: EcParamsP256) { Data($0) }

    case EcFieldBytesP384:
      return withUnsafeBytes(of: EcParamsP384) { Data($0) }

    case EcFieldBytesP521:
      return withUnsafeBytes(of: EcParamsP521) { Data($0) }

    default:
      return nil
    }
  }

  /// Field width in bytes for an uncompressed SEC 1 point, or nil when
  /// the data is not one.
  package static func fieldWidth(uncompressedPoint point: Data) -> Int? {
    guard point.first == EcUncompressedPointTag, point.count % elementCount == 1
    else { return nil }
    let width = (point.count - 1) / elementCount
    guard parameters(fieldWidth: width) != nil else { return nil }
    return width
  }

  /// Wraps an uncompressed point in the DER OCTET STRING that
  /// CKA_EC_POINT carries.
  package static func wrappedPoint(_ point: Data) -> Data {
    Data([Asn1OctetStringTag]) + Asn1.lengthOctets(point.count) + point
  }

  /// Converts an X9.62 DER ECDSA signature into raw CKM_ECDSA form.
  ///
  /// Each half is left-padded to the field width. Returns nil when the
  /// DER is malformed or a half exceeds the width.
  package static func rawSignature(fromDer der: Data, fieldWidth: Int) -> Data? {
    let bytes = Data(der)
    var index = 0
    guard Asn1.tag(bytes, &index) == Asn1SequenceTag,
      let bodyLength = Asn1.length(bytes, &index),
      bodyLength == bytes.count - index,
      let firstHalf = Asn1.integer(bytes, &index),
      let secondHalf = Asn1.integer(bytes, &index),
      index == bytes.count,
      let rPadded = padded(firstHalf, to: fieldWidth),
      let sPadded = padded(secondHalf, to: fieldWidth)
    else { return nil }
    return rPadded + sPadded
  }

  /// Left-pads an integer to the field width; nil when it is too wide.
  private static func padded(_ value: Data, to width: Int) -> Data? {
    guard value.count <= width else { return nil }
    return Data(repeating: 0, count: width - value.count) + value
  }
}
