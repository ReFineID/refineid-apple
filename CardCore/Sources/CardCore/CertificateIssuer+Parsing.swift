// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Strict Certificate and TBSCertificate parsing.
extension CertificateIssuer {
  /// Parses the exact signed certificate shape.
  internal static func parsed(_ encoded: Data) -> Parsed? {
    guard
      let certificate = SecCertificateCreateWithData(nil, encoded as CFData),
      let outer = Self.onlyElement(in: encoded, tag: DerValues.tagSequence)
    else {
      return nil
    }
    var reader = DerReader(encoded, within: outer)
    guard
      let tbs = Self.nextElement(
        from: &reader, in: encoded, tag: DerValues.tagSequence
      ),
      let algorithm = Self.nextElement(
        from: &reader, in: encoded, tag: DerValues.tagSequence
      ),
      let signature = Self.nextElement(
        from: &reader, in: encoded, tag: DerValues.tagBitString
      ),
      reader.isAtEnd
    else {
      return nil
    }
    let signatureContent = reader.contentData(of: signature)
    guard
      signatureContent.first == DerValues.bitStringNoUnusedBits,
      signatureContent.count > DerValues.bitStringPrefixByteCount,
      Self.innerSignatureAlgorithm(in: encoded, tbs: tbs)
        == reader.data(of: algorithm)
    else {
      return nil
    }
    return Parsed(
      certificate: certificate,
      encoded: encoded,
      signatureAlgorithm: reader.data(of: algorithm),
      signature: signatureContent.dropFirst(),
      signedBytes: reader.data(of: tbs),
      tbs: tbs
    )
  }

  /// Reads the AlgorithmIdentifier that is itself covered by the signature.
  private static func innerSignatureAlgorithm(
    in encoded: Data,
    tbs: DerReader.Element
  ) -> Data? {
    var reader = DerReader(encoded, within: tbs)
    guard var serial = Self.nextElement(from: &reader, in: encoded) else {
      return nil
    }
    if serial.tag == DerValues.tagContext0Constructed {
      guard
        Self.validVersion(serial, in: encoded),
        let following = Self.nextElement(from: &reader, in: encoded)
      else {
        return nil
      }
      serial = following
    }
    guard
      serial.tag == DerValues.tagInteger,
      let algorithm = Self.nextElement(
        from: &reader, in: encoded, tag: DerValues.tagSequence
      )
    else {
      return nil
    }
    return reader.data(of: algorithm)
  }

  /// Accepts the explicit v2 or v3 Certificate version values.
  private static func validVersion(
    _ wrapper: DerReader.Element,
    in encoded: Data
  ) -> Bool {
    var reader = DerReader(encoded, within: wrapper)
    guard
      let version = Self.nextElement(
        from: &reader, in: encoded, tag: DerValues.tagInteger
      ),
      reader.isAtEnd
    else {
      return false
    }
    let value = reader.contentData(of: version)
    return value == Data([DerValues.certificateVersionTwo])
      || value == Data([DerValues.certificateVersionThree])
  }

  /// One canonical element consuming its complete input.
  internal static func onlyElement(
    in encoded: Data,
    tag: UInt8
  ) -> DerReader.Element? {
    var reader = DerReader(encoded)
    guard
      let element = Self.nextElement(from: &reader, in: encoded, tag: tag),
      reader.isAtEnd
    else {
      return nil
    }
    return element
  }

  /// One canonical optional element, optionally constrained by tag.
  internal static func nextElement(
    from reader: inout DerReader,
    in encoded: Data
  ) -> DerReader.Element? {
    Self.nextElement(from: &reader, in: encoded, tag: nil)
  }

  /// One canonical optional element with the required tag.
  internal static func nextElement(
    from reader: inout DerReader,
    in encoded: Data,
    tag: UInt8
  ) -> DerReader.Element? {
    Self.nextElement(from: &reader, in: encoded, tag: Optional(tag))
  }

  /// One canonical optional element with an optional tag constraint.
  private static func nextElement(
    from reader: inout DerReader,
    in encoded: Data,
    tag: UInt8?
  ) -> DerReader.Element? {
    var candidate = reader
    guard let element = candidate.next() else { return nil }
    guard
      tag == nil || element.tag == tag,
      element.raw.upperBound <= encoded.count,
      candidate.data(of: element)
        == DerEncoder.tlv(element.tag, candidate.contentData(of: element))
    else {
      return nil
    }
    reader = candidate
    return element
  }
}
