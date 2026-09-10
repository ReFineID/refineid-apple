// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension TimestampCmsVerifier {
  // MARK: Static Functions

  /// The ECDSA digest one signature identifier names, if it names one.
  private static func ecdsaDigest(for encodedOid: Data) -> Digest? {
    switch encodedOid {
    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256):
      .sha256

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha384):
      .sha384

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha512):
      .sha512

    default:
      nil
    }
  }

  /// The RSA PKCS#1 digest one signature identifier names, if it names one.
  private static func rsaPkcs1Digest(for encodedOid: Data) -> Digest? {
    switch encodedOid {
    case DerEncoder.objectIdentifier(SignOids.sha256WithRsa):
      .sha256

    case DerEncoder.objectIdentifier(SignOids.sha384WithRsa):
      .sha384

    case DerEncoder.objectIdentifier(SignOids.sha512WithRsa):
      .sha512

    default:
      nil
    }
  }

  /// Maps a signature identifier while requiring its digest to agree.
  internal static func signatureAlgorithm(
    in encoded: Data,
    identifier: DerReader.Element,
    digest: Digest
  ) throws -> SecKeyAlgorithm {
    var reader = DerReader(encoded, within: identifier)
    guard let oid = reader.next(), oid.tag == DerValues.tagObjectIdentifier else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    let encodedOid = reader.data(of: oid)
    let parameters = reader.next()
    guard reader.isAtEnd else {
      throw TimestampTokenVerifier.Failure.malformed
    }

    if let ecdsaDigest = Self.ecdsaDigest(for: encodedOid) {
      guard parameters == nil, ecdsaDigest == digest else {
        throw TimestampTokenVerifier.Failure.invalidSignature
      }
      return digest.ecdsaAlgorithm
    }
    if let rsaDigest = Self.rsaPkcs1Digest(for: encodedOid) {
      try Self.requireNull(parameters)
      guard rsaDigest == digest else {
        throw TimestampTokenVerifier.Failure.invalidSignature
      }
      return digest.rsaPkcs1Algorithm
    }
    if encodedOid == DerEncoder.objectIdentifier(SignOids.rsaEncryption) {
      try Self.requireNull(parameters)
      return digest.rsaPkcs1Algorithm
    }
    if encodedOid == DerEncoder.objectIdentifier(SignOids.rsaPss) {
      guard let parameters else {
        throw TimestampTokenVerifier.Failure.invalidSignature
      }
      try Self.requirePssParameters(
        encoded: encoded, parameters: parameters, digest: digest
      )
      return digest.rsaPssAlgorithm
    }
    throw TimestampTokenVerifier.Failure.invalidSignature
  }

  /// Requires the explicit NULL carried by RSA PKCS#1 identifiers.
  private static func requireNull(_ element: DerReader.Element?) throws {
    guard
      let element,
      element.tag == DerValues.tagNull,
      element.content.isEmpty
    else { throw TimestampTokenVerifier.Failure.invalidSignature }
  }

  /// Accepts the unambiguous RFC 8017 PSS profile matching the CMS digest.
  private static func requirePssParameters(
    encoded: Data,
    parameters: DerReader.Element,
    digest: Digest
  ) throws {
    guard parameters.tag == DerValues.tagSequence else {
      throw TimestampTokenVerifier.Failure.invalidSignature
    }
    var reader = DerReader(encoded, within: parameters)
    guard
      let hash = reader.next(), hash.tag == DerValues.tagContext0Constructed,
      let mask = reader.next(), mask.tag == DerValues.tagContext1Constructed,
      let salt = reader.next(), salt.tag == DerValues.tagContext2Constructed,
      reader.isAtEnd,
      try Self.explicitDigest(in: encoded, wrapper: hash) == digest,
      try Self.maskDigest(in: encoded, wrapper: mask) == digest,
      try Self.explicitInteger(in: encoded, wrapper: salt) == digest.byteCount
    else { throw TimestampTokenVerifier.Failure.invalidSignature }
  }

  private static func explicitDigest(
    in encoded: Data,
    wrapper: DerReader.Element
  ) throws -> Digest {
    var reader = DerReader(encoded, within: wrapper)
    guard let identifier = reader.next(), reader.isAtEnd else {
      throw TimestampTokenVerifier.Failure.invalidSignature
    }
    return try Self.digest(in: encoded, identifier: identifier)
  }

  private static func maskDigest(
    in encoded: Data,
    wrapper: DerReader.Element
  ) throws -> Digest {
    var explicit = DerReader(encoded, within: wrapper)
    guard
      let identifier = explicit.next(),
      identifier.tag == DerValues.tagSequence,
      explicit.isAtEnd
    else { throw TimestampTokenVerifier.Failure.invalidSignature }
    var fields = DerReader(encoded, within: identifier)
    guard
      let oid = fields.next(),
      fields.data(of: oid)
        == DerEncoder.objectIdentifier(SignOids.maskGenerationFunction1),
      let digestIdentifier = fields.next(),
      fields.isAtEnd
    else { throw TimestampTokenVerifier.Failure.invalidSignature }
    return try Self.digest(in: encoded, identifier: digestIdentifier)
  }

  private static func explicitInteger(
    in encoded: Data,
    wrapper: DerReader.Element
  ) throws -> Int {
    var reader = DerReader(encoded, within: wrapper)
    guard
      let integer = reader.next(), integer.tag == DerValues.tagInteger,
      let value = reader.integerValue(of: integer),
      reader.isAtEnd
    else { throw TimestampTokenVerifier.Failure.invalidSignature }
    return value
  }
}
