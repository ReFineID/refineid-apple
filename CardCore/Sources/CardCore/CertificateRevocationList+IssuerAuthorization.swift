// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension CertificateRevocationList {
  /// id-ce-keyUsage (RFC 5280 section 4.2.1.3).
  private static let keyUsageOid = "2.5.29.15"

  /// Signature, issuer, validity, subject, and public-key sequences.
  private static let certificateSequencesThroughPublicKey = 5

  /// Bit mask for cRLSign in the first KeyUsage payload octet.
  private static let crlSignKeyUsageBit = UInt8(1) << UInt8(1)

  /// Applies the issuer certificate's KeyUsage restriction to CRL signing.
  ///
  /// RFC 5280 treats an omitted KeyUsage as unrestricted. When the extension
  /// is present, its cRLSign bit must explicitly authorize this operation.
  internal static func certificateAllowsCrlSigning(
    in encoded: Data,
    tbs: DerReader.Element
  ) throws -> Bool {
    var reader = DerReader(encoded, within: tbs)
    var serial = try Self.requiredElement(from: &reader, in: encoded)
    if serial.tag == DerValues.tagContext0Constructed {
      serial = try Self.requiredElement(
        from: &reader,
        in: encoded,
        tag: DerValues.tagInteger
      )
    }
    guard serial.tag == DerValues.tagInteger else {
      throw ValidationFailure.malformed
    }
    for _ in 0..<Self.certificateSequencesThroughPublicKey {
      _ = try Self.requiredElement(
        from: &reader,
        in: encoded,
        tag: DerValues.tagSequence
      )
    }
    return try Self.crlSignFromTrailingCertificateFields(
      encoded,
      reader: &reader
    )
  }

  /// Finds the sole Extensions wrapper after SubjectPublicKeyInfo.
  private static func crlSignFromTrailingCertificateFields(
    _ encoded: Data,
    reader: inout DerReader
  ) throws -> Bool {
    var foundExtensions = false
    var allowsCrlSigning = true
    while let trailing = try Self.nextElement(from: &reader, in: encoded) {
      switch trailing.tag {
      case DerValues.tagContext1Primitive, DerValues.tagContext2Primitive:
        continue

      case DerValues.tagContext3Constructed:
        guard !foundExtensions else { throw ValidationFailure.malformed }
        allowsCrlSigning = try Self.keyUsageAllowsCrlSigning(
          in: encoded,
          wrapper: trailing
        )
        foundExtensions = true

      default:
        throw ValidationFailure.malformed
      }
    }
    guard reader.isAtEnd else { throw ValidationFailure.malformed }
    return allowsCrlSigning
  }

  /// Reads KeyUsage from a certificate Extensions wrapper.
  private static func keyUsageAllowsCrlSigning(
    in encoded: Data,
    wrapper: DerReader.Element
  ) throws -> Bool {
    var wrapperReader = DerReader(encoded, within: wrapper)
    let sequence = try Self.requiredElement(
      from: &wrapperReader,
      in: encoded,
      tag: DerValues.tagSequence
    )
    guard wrapperReader.isAtEnd else { throw ValidationFailure.malformed }

    var reader = DerReader(encoded, within: sequence)
    var foundKeyUsage = false
    var allowsCrlSigning = false
    while let extensionElement = try Self.nextElement(from: &reader, in: encoded) {
      let parsed = try Self.certificateExtension(
        in: encoded,
        element: extensionElement
      )
      guard parsed.identifier == DerEncoder.objectIdentifier(Self.keyUsageOid) else {
        continue
      }
      guard !foundKeyUsage else { throw ValidationFailure.malformed }
      foundKeyUsage = true
      allowsCrlSigning = try Self.keyUsageContainsCrlSign(parsed.value)
    }
    guard reader.isAtEnd else { throw ValidationFailure.malformed }
    return !foundKeyUsage || allowsCrlSigning
  }

  /// Parses the identifier and opaque extnValue of one certificate Extension.
  private static func certificateExtension(
    in encoded: Data,
    element: DerReader.Element
  ) throws -> (identifier: Data, value: Data) {
    guard element.tag == DerValues.tagSequence else {
      throw ValidationFailure.malformed
    }
    var reader = DerReader(encoded, within: element)
    let identifier = try Self.requiredElement(
      from: &reader,
      in: encoded,
      tag: DerValues.tagObjectIdentifier
    )
    var value = try Self.requiredElement(from: &reader, in: encoded)
    if value.tag == DerValues.tagBoolean {
      guard reader.contentData(of: value) == Data([DerValues.booleanTrue]) else {
        throw ValidationFailure.malformed
      }
      value = try Self.requiredElement(
        from: &reader,
        in: encoded,
        tag: DerValues.tagOctetString
      )
    }
    guard value.tag == DerValues.tagOctetString, reader.isAtEnd else {
      throw ValidationFailure.malformed
    }
    return (reader.data(of: identifier), reader.contentData(of: value))
  }

  /// Reads cRLSign from a minimally encoded KeyUsage BIT STRING.
  private static func keyUsageContainsCrlSign(_ encoded: Data) throws -> Bool {
    _ = try Self.onlyElement(in: encoded, tag: DerValues.tagBitString)
    var reader = DerReader(encoded)
    guard let bits = reader.next() else { throw ValidationFailure.malformed }
    let content = reader.contentData(of: bits)
    guard
      let unusedBitCount = content.first,
      unusedBitCount < UInt8.bitWidth,
      let firstUsageByte = content.dropFirst().first,
      let lastUsageByte = content.last
    else {
      throw ValidationFailure.malformed
    }
    let unusedMask = UInt8.max >> (UInt8.bitWidth - Int(unusedBitCount))
    guard lastUsageByte & unusedMask == 0 else {
      throw ValidationFailure.malformed
    }
    return firstUsageByte & Self.crlSignKeyUsageBit != 0
  }
}
