// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Security

/// Portable authentication of the CMS envelope around one RFC 3161 TSTInfo.
///
/// CryptoTokenKit's historical `CMSDecoder` is not available on iOS. This
/// verifier deliberately walks the small CMS subset used by timestamp tokens
/// and hands only the final public-key operation to Security. The signed
/// attributes are verified in their exact DER SET encoding, never rebuilt.
internal enum TimestampCmsVerifier {
  // MARK: Nested Types

  /// The CMS state needed by the timestamp certificate-policy verifier.
  internal struct Authenticated {
    internal let signerCertificate: Data
    internal let embeddedCertificates: [Data]
    internal let trust: SecTrust
  }

  /// Digest algorithms accepted for timestamp signatures.
  private enum Digest: Equatable {
    case sha256
    case sha384
    case sha512

    // MARK: Computed Properties

    var byteCount: Int {
      switch self {
      case .sha256:
        SHA256.byteCount

      case .sha384:
        SHA384.byteCount

      case .sha512:
        SHA512.byteCount
      }
    }

    var ecdsaAlgorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .ecdsaSignatureMessageX962SHA256

      case .sha384:
        .ecdsaSignatureMessageX962SHA384

      case .sha512:
        .ecdsaSignatureMessageX962SHA512
      }
    }

    var rsaPkcs1Algorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .rsaSignatureMessagePKCS1v15SHA256

      case .sha384:
        .rsaSignatureMessagePKCS1v15SHA384

      case .sha512:
        .rsaSignatureMessagePKCS1v15SHA512
      }
    }

    var rsaPssAlgorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .rsaSignatureMessagePSSSHA256

      case .sha384:
        .rsaSignatureMessagePSSSHA384

      case .sha512:
        .rsaSignatureMessagePSSSHA512
      }
    }

    // MARK: Functions

    func hash(_ data: Data) -> Data {
      switch self {
      case .sha256:
        Data(SHA256.hash(data: data))

      case .sha384:
        Data(SHA384.hash(data: data))

      case .sha512:
        Data(SHA512.hash(data: data))
      }
    }
  }

  /// One parsed signer and the exact values its signature covers.
  private struct Signer {
    let identifier: DerReader.Element
    let digest: Digest
    let signedAttributes: DerReader.Element
    let signatureAlgorithm: SecKeyAlgorithm
    let signature: Data
  }

  /// The SignedData fields used by one timestamp token.
  private struct Layout {
    let digest: Digest
    let content: Data
    let signerInfo: DerReader.Element
  }

  // MARK: Static Functions

  /// Authenticates the sole signer and exact encapsulated content.
  internal static func authenticate(
    token: Data,
    expectedContent: Data
  ) throws -> Authenticated {
    let layout = try Self.layout(in: token)
    guard layout.content == expectedContent else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    let signer = try Self.signer(in: token, element: layout.signerInfo)
    guard layout.digest == signer.digest else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    try Self.verifySignedAttributes(
      in: token,
      element: signer.signedAttributes,
      digest: signer.digest,
      content: expectedContent
    )

    let embedded = CmsCertificates.inside(token)
    guard !embedded.isEmpty else {
      throw TimestampTokenVerifier.Failure.signerCertificateMissing
    }
    guard
      let signerData = embedded.first(where: {
        Self.identifier(signer.identifier, in: token, matches: $0)
      }),
      let signerCertificate = SecCertificateCreateWithData(
        nil, signerData as CFData
      )
    else {
      throw TimestampTokenVerifier.Failure.signerCertificateMissing
    }

    let attributes = DerEncoder.retagged(
      Self.data(of: signer.signedAttributes, in: token),
      to: DerValues.tagSet
    )
    guard
      CertificateRevocationList.signatureIsValid(
        signer.signature,
        over: attributes,
        with: signerCertificate,
        algorithm: signer.signatureAlgorithm
      )
    else {
      throw TimestampTokenVerifier.Failure.invalidSignature
    }

    let certificates = [signerData] + embedded.filter { $0 != signerData }
    let parsed = certificates.compactMap {
      SecCertificateCreateWithData(nil, $0 as CFData)
    }
    guard
      parsed.count == certificates.count,
      let policy = SecPolicyCreateWithProperties(
        kSecPolicyAppleTimeStamping, nil
      )
    else {
      throw TimestampTokenVerifier.Failure.malformed
    }
    var created: SecTrust?
    guard
      SecTrustCreateWithCertificates(
        parsed as CFArray, policy, &created
      ) == errSecSuccess,
      let trust = created
    else {
      throw TimestampTokenVerifier.Failure.signerCertificateMissing
    }
    return Authenticated(
      signerCertificate: signerData,
      embeddedCertificates: embedded,
      trust: trust
    )
  }

  /// Parses the complete ContentInfo and requires one digest and one signer.
  private static func layout(in token: Data) throws -> Layout {
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
  private static func signer(
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
  private static func digest(
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

  /// Maps a signature identifier while requiring its digest to agree.
  private static func signatureAlgorithm(
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

    let ecdsaDigest: Digest?
    switch encodedOid {
    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha256):
      ecdsaDigest = .sha256

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha384):
      ecdsaDigest = .sha384

    case DerEncoder.objectIdentifier(SignOids.ecdsaWithSha512):
      ecdsaDigest = .sha512

    default:
      ecdsaDigest = nil
    }
    if let ecdsaDigest {
      guard parameters == nil, ecdsaDigest == digest else {
        throw TimestampTokenVerifier.Failure.invalidSignature
      }
      return digest.ecdsaAlgorithm
    }

    let rsaDigest: Digest?
    switch encodedOid {
    case DerEncoder.objectIdentifier(SignOids.sha256WithRsa):
      rsaDigest = .sha256

    case DerEncoder.objectIdentifier(SignOids.sha384WithRsa):
      rsaDigest = .sha384

    case DerEncoder.objectIdentifier(SignOids.sha512WithRsa):
      rsaDigest = .sha512

    default:
      rsaDigest = nil
    }
    if let rsaDigest {
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

  /// Requires content-type and message-digest exactly once in canonical DER.
  private static func verifySignedAttributes(
    in token: Data,
    element: DerReader.Element,
    digest: Digest,
    content: Data
  ) throws {
    var reader = DerReader(token, within: element)
    var previous: Data?
    var contentTypeCount = 0
    var messageDigestCount = 0
    while let attribute = reader.next() {
      guard attribute.tag == DerValues.tagSequence else {
        throw TimestampTokenVerifier.Failure.malformed
      }
      let raw = reader.data(of: attribute)
      if let previous, !previous.lexicographicallyPrecedes(raw) {
        throw TimestampTokenVerifier.Failure.malformed
      }
      previous = raw
      var fields = DerReader(token, within: attribute)
      guard
        let oid = fields.next(), oid.tag == DerValues.tagObjectIdentifier,
        let values = fields.next(), values.tag == DerValues.tagSet,
        fields.isAtEnd
      else { throw TimestampTokenVerifier.Failure.malformed }
      let identifier = fields.data(of: oid)
      if identifier == DerEncoder.objectIdentifier(SignOids.contentType) {
        contentTypeCount += 1
        var value = DerReader(token, within: values)
        guard
          let type = value.next(),
          value.data(of: type) == DerEncoder.objectIdentifier(SignOids.tstInfo),
          value.isAtEnd
        else { throw TimestampTokenVerifier.Failure.malformed }
      } else if identifier == DerEncoder.objectIdentifier(SignOids.messageDigest) {
        messageDigestCount += 1
        var value = DerReader(token, within: values)
        guard
          let octets = value.next(), octets.tag == DerValues.tagOctetString,
          value.isAtEnd,
          ConstantTimeComparison.equal(
            value.contentData(of: octets), digest.hash(content)
          )
        else { throw TimestampTokenVerifier.Failure.invalidSignature }
      }
    }
    guard
      reader.isAtEnd,
      contentTypeCount == 1,
      messageDigestCount == 1
    else { throw TimestampTokenVerifier.Failure.malformed }
  }

  /// Matches either CMS SignerIdentifier form to an embedded certificate.
  private static func identifier(
    _ identifier: DerReader.Element,
    in token: Data,
    matches certificate: Data
  ) -> Bool {
    guard let facts = CertificateFacts(der: certificate) else { return false }
    if identifier.tag == DerValues.tagSequence {
      var reader = DerReader(token, within: identifier)
      guard
        let issuer = reader.next(),
        let serial = reader.next(), serial.tag == DerValues.tagInteger,
        reader.isAtEnd
      else { return false }
      return reader.data(of: issuer) == facts.issuerName
        && reader.contentData(of: serial) == facts.serialNumber
    }
    if identifier.tag == DerValues.tagContext0Primitive {
      return Self.subjectKeyIdentifier(in: certificate)
        == Self.content(of: identifier, in: token)
    }
    return false
  }

  /// Extracts id-ce-subjectKeyIdentifier from one X.509 certificate.
  private static func subjectKeyIdentifier(in certificate: Data) -> Data? {
    let issuedNameFieldCount: Int = 5

    var outer = DerReader(certificate)
    guard
      let certificateElement = outer.next(), outer.isAtEnd
    else { return nil }
    var body = DerReader(certificate, within: certificateElement)
    guard let tbs = body.next() else { return nil }
    var fields = DerReader(certificate, within: tbs)
    guard var field = fields.next() else { return nil }
    if field.tag == DerValues.tagContext0Constructed {
      guard let next = fields.next() else { return nil }
      field = next
    }
    guard field.tag == DerValues.tagInteger else { return nil }
    // signature, issuer, validity, subject and SubjectPublicKeyInfo.
    for _ in 0..<issuedNameFieldCount {
      guard fields.next() != nil else { return nil }
    }
    while let candidate = fields.next() {
      guard candidate.tag == DerValues.tagContext3Constructed else { continue }
      var wrapper = DerReader(certificate, within: candidate)
      guard
        let extensions = wrapper.next(), extensions.tag == DerValues.tagSequence,
        wrapper.isAtEnd
      else { return nil }
      var list = DerReader(certificate, within: extensions)
      while let item = list.next() {
        guard item.tag == DerValues.tagSequence else { return nil }
        var extensionFields = DerReader(certificate, within: item)
        guard
          let oid = extensionFields.next(),
          oid.tag == DerValues.tagObjectIdentifier
        else { return nil }
        var value = extensionFields.next()
        if value?.tag == DerValues.tagBoolean {
          value = extensionFields.next()
        }
        guard
          let value, value.tag == DerValues.tagOctetString,
          extensionFields.isAtEnd
        else { return nil }
        guard
          extensionFields.data(of: oid)
            == DerEncoder.objectIdentifier(SignOids.subjectKeyIdentifier)
        else { continue }
        let encoded = extensionFields.contentData(of: value)
        var inner = DerReader(encoded)
        guard
          let keyIdentifier = inner.next(),
          keyIdentifier.tag == DerValues.tagOctetString,
          inner.isAtEnd
        else { return nil }
        return inner.contentData(of: keyIdentifier)
      }
      return nil
    }
    return nil
  }

  private static func data(
    of element: DerReader.Element,
    in encoded: Data
  ) -> Data {
    let reader = DerReader(encoded)
    return reader.data(of: element)
  }

  private static func content(
    of element: DerReader.Element,
    in encoded: Data
  ) -> Data {
    let reader = DerReader(encoded)
    return reader.contentData(of: element)
  }
}
