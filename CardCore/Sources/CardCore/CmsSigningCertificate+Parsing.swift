// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension CmsSigningCertificate {
  /// The signed attributes field of the token's sole SignerInfo.
  internal static func signedAttributes(
    in token: Data
  ) throws -> DerReader.Element {
    let signer = try Self.signerInfo(in: token)
    var reader = DerReader(token, within: signer)
    guard
      reader.next() != nil,
      reader.next() != nil,
      reader.next() != nil,
      let attributes = reader.next(),
      attributes.tag == DerValues.tagContext0Constructed
    else {
      throw Failure.malformed
    }
    return attributes
  }

  /// The sole SignerInfo inside SignedData.
  private static func signerInfo(in token: Data) throws -> DerReader.Element {
    let signedData = try Self.signedData(in: token)
    var signed = DerReader(token, within: signedData)
    guard signed.next() != nil, signed.next() != nil, signed.next() != nil else {
      throw Failure.malformed
    }
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
    else {
      throw Failure.malformed
    }
    var signers = DerReader(token, within: signerInfos)
    guard
      let signer = signers.next(),
      signer.tag == DerValues.tagSequence,
      signers.isAtEnd
    else {
      throw Failure.malformed
    }
    return signer
  }

  /// The SignedData element inside the token's ContentInfo.
  private static func signedData(in token: Data) throws -> DerReader.Element {
    var outer = DerReader(token)
    guard
      let contentInfo = outer.next(),
      contentInfo.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      throw Failure.malformed
    }
    var info = DerReader(token, within: contentInfo)
    guard
      let type = info.next(),
      info.data(of: type) == DerEncoder.objectIdentifier(SignOids.signedData),
      let wrapper = info.next(),
      wrapper.tag == DerValues.tagContext0Constructed,
      info.isAtEnd
    else {
      throw Failure.malformed
    }
    var wrapped = DerReader(token, within: wrapper)
    guard
      let signedData = wrapped.next(),
      signedData.tag == DerValues.tagSequence,
      wrapped.isAtEnd
    else {
      throw Failure.malformed
    }
    return signedData
  }

  /// The first certificate reference in one attribute value.
  internal static func reference(
    in values: DerReader.Element,
    token: Data,
    versionTwo: Bool
  ) throws -> Reference {
    var valueSet = DerReader(token, within: values)
    guard
      let value = valueSet.next(),
      value.tag == DerValues.tagSequence,
      valueSet.isAtEnd
    else {
      throw Failure.malformed
    }
    var signingCertificate = DerReader(token, within: value)
    guard
      let certificates = signingCertificate.next(),
      certificates.tag == DerValues.tagSequence
    else {
      throw Failure.malformed
    }
    var list = DerReader(token, within: certificates)
    guard let first = list.next(), first.tag == DerValues.tagSequence else {
      throw Failure.malformed
    }
    var identifier = DerReader(token, within: first)
    var field = identifier.next()
    let algorithm: DigestAlgorithm
    if versionTwo, let candidate = field, candidate.tag == DerValues.tagSequence {
      algorithm = try Self.digestAlgorithm(identifier.data(of: candidate))
      field = identifier.next()
    } else {
      algorithm = versionTwo ? .sha256 : .sha1
    }
    guard let hash = field, hash.tag == DerValues.tagOctetString else {
      throw Failure.malformed
    }
    let issuerSerial = identifier.next().map { identifier.data(of: $0) }
    guard identifier.isAtEnd else { throw Failure.malformed }
    return Reference(
      algorithm: algorithm,
      digest: identifier.contentData(of: hash),
      issuerSerial: issuerSerial
    )
  }

  /// A supported ESSCertIDv2 hash AlgorithmIdentifier.
  internal static func digestAlgorithm(
    _ encoded: Data
  ) throws -> DigestAlgorithm {
    var outer = DerReader(encoded)
    guard
      let sequence = outer.next(),
      sequence.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      throw Failure.malformed
    }
    var reader = DerReader(encoded, within: sequence)
    guard let oid = reader.next() else { throw Failure.malformed }
    if let parameters = reader.next() {
      guard
        parameters.tag == DerValues.tagNull,
        reader.contentData(of: parameters).isEmpty
      else {
        throw Failure.malformed
      }
    }
    guard reader.isAtEnd else { throw Failure.malformed }
    switch reader.data(of: oid) {
    case DerEncoder.objectIdentifier(SignOids.sha1):
      return .sha1

    case DerEncoder.objectIdentifier(SignOids.sha256):
      return .sha256

    case DerEncoder.objectIdentifier(SignOids.sha384):
      return .sha384

    case DerEncoder.objectIdentifier(SignOids.sha512):
      return .sha512

    default:
      throw Failure.unsupportedHash
    }
  }

  /// Whether an optional ESS issuerSerial names the signer certificate.
  internal static func matches(
    issuerSerial encoded: Data,
    certificate: CertificateFacts
  ) -> Bool {
    var outer = DerReader(encoded)
    guard
      let sequence = outer.next(),
      sequence.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      return false
    }
    var reader = DerReader(encoded, within: sequence)
    guard
      let names = reader.next(),
      names.tag == DerValues.tagSequence,
      let serial = reader.next(),
      serial.tag == DerValues.tagInteger,
      reader.isAtEnd,
      reader.contentData(of: serial) == certificate.serialNumber
    else {
      return false
    }
    var nameReader = DerReader(encoded, within: names)
    while let name = nameReader.next() {
      guard name.tag == DerValues.tagContext4Constructed else { continue }
      var directory = DerReader(encoded, within: name)
      guard let distinguishedName = directory.next(), directory.isAtEnd else {
        return false
      }
      if directory.data(of: distinguishedName) == certificate.issuerName {
        return true
      }
    }
    return false
  }
}
