// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A minimal DER writer for the document-signing structures.
///
/// Everything here is definite-length with minimal length octets
/// (X.690 §10.1), which is what DER is; there is no BER reader or
/// writer to confuse it with. Object identifiers are encoded from
/// dotted notation arithmetically, so the encoded forms exist in
/// exactly one place - this one.
public enum DerEncoder {
  /// One tag-length-value: the tag, minimal length octets, content.
  public static func tlv(_ tag: UInt8, _ content: Data) -> Data {
    var out = Data([tag])
    out.append(lengthOctets(content.count))
    out.append(content)
    return out
  }

  /// SEQUENCE of already-encoded elements, in the given order.
  public static func sequence(_ elements: [Data]) -> Data {
    tlv(DerValues.tagSequence, elements.reduce(Data(), +))
  }

  /// SET OF already-encoded elements, sorted by encoding as DER
  /// requires (X.690 §11.6).
  public static func setOf(_ elements: [Data]) -> Data {
    let sorted = elements.sorted { left, right in
      left.lexicographicallyPrecedes(right)
    }
    return tlv(DerValues.tagSet, sorted.reduce(Data(), +))
  }

  /// INTEGER from magnitude bytes: leading zeros stripped, a zero
  /// octet prepended when the top bit is set, zero encoded as one
  /// zero octet.
  public static func unsignedInteger(_ magnitude: Data) -> Data {
    var bytes = Array(magnitude.drop { byte in byte == 0 })
    if bytes.isEmpty {
      bytes = [0]
    }
    if let first = bytes.first, first & DerValues.signBitMask != 0 {
      bytes.insert(0, at: 0)
    }
    return tlv(DerValues.tagInteger, Data(bytes))
  }

  /// A small non-negative INTEGER.
  public static func integer(_ value: Int) -> Data {
    var magnitude: [UInt8] = []
    var remaining = value
    repeat {
      magnitude.insert(UInt8(remaining & Int(UInt8.max)), at: 0)
      remaining >>= UInt8.bitWidth
    } while remaining > 0
    return unsignedInteger(Data(magnitude))
  }

  /// BOOLEAN TRUE; DER never writes a default FALSE.
  public static func booleanTrue() -> Data {
    tlv(DerValues.tagBoolean, Data([DerValues.booleanTrue]))
  }

  /// OCTET STRING.
  public static func octetString(_ content: Data) -> Data {
    tlv(DerValues.tagOctetString, content)
  }

  /// NULL, whose DER value has empty content.
  public static func null() -> Data {
    tlv(DerValues.tagNull, Data())
  }

  /// OBJECT IDENTIFIER from dotted notation (X.690 §8.19).
  ///
  /// The dotted strings live beside their names in `SignOids`;
  /// an unparseable string is a programming error and answers an
  /// empty encoding, which no consumer accepts silently.
  public static func objectIdentifier(_ dotted: String) -> Data {
    let arcs = dotted.split(separator: ".").compactMap { part in UInt(part) }
    guard arcs.count >= DerValues.oidMinimumArcs else {
      return Data()
    }
    var content = arcEncoding(
      arcs[0] * DerValues.oidFirstArcMultiplier + arcs[1]
    )
    for arc in arcs.dropFirst(DerValues.oidSharedArcs) {
      content.append(arcEncoding(arc))
    }
    return tlv(DerValues.tagObjectIdentifier, content)
  }

  /// Retags an encoding in place.
  ///
  /// The identifier octet changes; the length and content do not.
  /// How signed attributes become the `[0] IMPLICIT` form after the
  /// SET form was signed (RFC 5652 §5.4).
  public static func retagged(_ encoded: Data, to tag: UInt8) -> Data {
    var out = encoded
    out[out.startIndex] = tag
    return out
  }

  /// Minimal length octets: short form through 127, long form above.
  private static func lengthOctets(_ length: Int) -> Data {
    if length <= DerValues.shortFormMaximum {
      return Data([UInt8(length)])
    }
    var magnitude: [UInt8] = []
    var remaining = length
    while remaining > 0 {
      magnitude.insert(UInt8(remaining & Int(UInt8.max)), at: 0)
      remaining >>= UInt8.bitWidth
    }
    return Data([DerValues.longFormMask | UInt8(magnitude.count)] + magnitude)
  }

  /// One arc in base 128, high bit marking continuation.
  private static func arcEncoding(_ arc: UInt) -> Data {
    var septets: [UInt8] = [UInt8(arc & DerValues.oidArcMask)]
    var remaining = arc >> DerValues.oidArcBits
    while remaining > 0 {
      septets.insert(
        DerValues.oidContinuationBit | UInt8(remaining & DerValues.oidArcMask),
        at: 0
      )
      remaining >>= DerValues.oidArcBits
    }
    return Data(septets)
  }
}
