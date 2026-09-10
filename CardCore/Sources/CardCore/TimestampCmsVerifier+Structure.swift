// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension TimestampCmsVerifier {
  // MARK: Nested Types

  /// One parsed signer and the exact values its signature covers.
  internal struct Signer {
    internal let identifier: DerReader.Element
    internal let digest: Digest
    internal let signedAttributes: DerReader.Element
    internal let signatureAlgorithm: SecKeyAlgorithm
    internal let signature: Data
  }

  /// The SignedData fields used by one timestamp token.
  internal struct Layout {
    internal let digest: Digest
    internal let content: Data
    internal let signerInfo: DerReader.Element
  }

  // MARK: Static Functions

  /// Parses the complete ContentInfo and requires one digest and one signer.
  internal static func layout(in token: Data) throws -> Layout {
    var outer = DerReader(token)
    guard
      let contentInfo = outer.next(),
      contentInfo.tag == DerValues.tagSequence,
      outer.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    var info = DerReader(token, within: contentInfo)
    guard
      let type = info.next(),
      info.data(of: type) == DerEncoder.objectIdentifier(SignOids.signedData),
      let wrapper = info.next(),
      wrapper.tag == DerValues.tagContext0Constructed,
      info.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    var wrapped = DerReader(token, within: wrapper)
    guard
      let signedData = wrapped.next(),
      signedData.tag == DerValues.tagSequence,
      wrapped.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }

    var signed = DerReader(token, within: signedData)
    guard
      let version = signed.next(), version.tag == DerValues.tagInteger,
      let algorithms = signed.next(), algorithms.tag == DerValues.tagSet,
      let encapsulated = signed.next(), encapsulated.tag == DerValues.tagSequence
    else { throw TimestampTokenVerifier.Failure.malformed }
    let digest = try Self.soleDigest(in: token, set: algorithms)
    let content = try Self.encapsulatedContent(in: token, element: encapsulated)

    var candidate = signed.next()
    if candidate?.tag == DerValues.tagContext0Constructed {
      candidate = signed.next()
    }
    if candidate?.tag == DerValues.tagContext1Constructed {
      candidate = signed.next()
    }
    guard
      let signerInfos = candidate,
      signerInfos.tag == DerValues.tagSet,
      signed.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    var signers = DerReader(token, within: signerInfos)
    guard
      let signer = signers.next(), signer.tag == DerValues.tagSequence,
      signers.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    return Layout(digest: digest, content: content, signerInfo: signer)
  }

  /// Requires the RFC 3161 eContentType and its one explicit OCTET STRING.
  private static func encapsulatedContent(
    in token: Data,
    element: DerReader.Element
  ) throws -> Data {
    var contentInfo = DerReader(token, within: element)
    guard
      let type = contentInfo.next(),
      type.tag == DerValues.tagObjectIdentifier,
      contentInfo.data(of: type) == DerEncoder.objectIdentifier(SignOids.tstInfo),
      let wrapper = contentInfo.next(),
      wrapper.tag == DerValues.tagContext0Constructed,
      contentInfo.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    var wrapped = DerReader(token, within: wrapper)
    guard
      let octets = wrapped.next(), octets.tag == DerValues.tagOctetString,
      wrapped.isAtEnd
    else { throw TimestampTokenVerifier.Failure.malformed }
    return wrapped.contentData(of: octets)
  }

  /// Parses one complete SignerInfo and rejects trailing fields.
  internal static func signer(
    in token: Data,
    element: DerReader.Element
  ) throws -> Signer {
    var reader = DerReader(token, within: element)
    guard
      let version = reader.next(), version.tag == DerValues.tagInteger,
      let identifier = reader.next(),
      let digestIdentifier = reader.next(),
      digestIdentifier.tag == DerValues.tagSequence,
      let attributes = reader.next(),
      attributes.tag == DerValues.tagContext0Constructed,
      let signatureIdentifier = reader.next(),
      signatureIdentifier.tag == DerValues.tagSequence,
      let signature = reader.next(), signature.tag == DerValues.tagOctetString
    else { throw TimestampTokenVerifier.Failure.malformed }
    if let unsigned = reader.next() {
      guard unsigned.tag == DerValues.tagContext1Constructed else {
        throw TimestampTokenVerifier.Failure.malformed
      }
    }
    guard reader.isAtEnd else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    let digest = try Self.digest(in: token, identifier: digestIdentifier)
    let signatureAlgorithm = try Self.signatureAlgorithm(
      in: token,
      identifier: signatureIdentifier,
      digest: digest
    )
    return Signer(
      identifier: identifier,
      digest: digest,
      signedAttributes: attributes,
      signatureAlgorithm: signatureAlgorithm,
      signature: reader.contentData(of: signature)
    )
  }

  /// Requires exactly one SignedData digest identifier.
  private static func soleDigest(
    in token: Data,
    set: DerReader.Element
  ) throws -> Digest {
    var reader = DerReader(token, within: set)
    guard let identifier = reader.next(), reader.isAtEnd else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    return try Self.digest(in: token, identifier: identifier)
  }

  /// Parses a SHA-2 AlgorithmIdentifier with absent or NULL parameters.
  internal static func digest(
    in encoded: Data,
    identifier: DerReader.Element
  ) throws -> Digest {
    guard identifier.tag == DerValues.tagSequence else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    var reader = DerReader(encoded, within: identifier)
    guard let oid = reader.next(), oid.tag == DerValues.tagObjectIdentifier else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    if let parameters = reader.next() {
      guard
        parameters.tag == DerValues.tagNull,
        parameters.content.isEmpty
      else { throw TimestampTokenVerifier.Failure.invalidSignature }
    }
    guard reader.isAtEnd else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    switch reader.data(of: oid) {
    case DerEncoder.objectIdentifier(SignOids.sha256):
      return .sha256

    case DerEncoder.objectIdentifier(SignOids.sha384):
      return .sha384

    case DerEncoder.objectIdentifier(SignOids.sha512):
      return .sha512

    default:
      throw TimestampTokenVerifier.Failure.invalidSignature
    }
  }
}
