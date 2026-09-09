// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Computes the total encoded byte length of the DER object at the start
/// of a buffer, once enough of its header is present.
///
/// The card refuses a READ BINARY whose length overruns the file, so a
/// certificate must be read to its exact size. Every file this driver
/// reads is a single DER object, so its own header carries that size:
/// one tag byte, then a short- or long-form length. This reads only the
/// generic TLV length - not the X.509 contents.
public enum DerObjectLength {
  /// Bytes before the length value: one tag byte plus the first length
  /// octet.
  private static let tagAndFirstLengthOctet = 2

  /// Most length octets any file this driver reads needs.
  ///
  /// A 16-bit content length covers the largest directly addressable
  /// card file.
  private static let maximumLengthOctets = 2

  /// The total object length (header + content), or nil when `prefix`
  /// does not yet contain the whole header or the header is malformed.
  public static func total(of prefix: Data) -> Int? {
    let bytes = Array(prefix)
    guard bytes.count >= Self.tagAndFirstLengthOctet else { return nil }
    let firstLengthOctet = bytes[1]
    if firstLengthOctet & Iso7816Values.derLongFormMask == 0 {
      return Self.tagAndFirstLengthOctet + Int(firstLengthOctet)
    }
    let octetCount = Int(firstLengthOctet & Iso7816Values.derLengthCountMask)
    guard octetCount >= 1, octetCount <= Self.maximumLengthOctets else {
      return nil
    }
    let header = Self.tagAndFirstLengthOctet + octetCount
    guard bytes.count >= header else { return nil }
    var length = 0
    for index in 0..<octetCount {
      length =
        length << Iso7816Values.byteShift
        | Int(bytes[Self.tagAndFirstLengthOctet + index])
    }
    return header + length
  }
}
