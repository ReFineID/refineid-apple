// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension TimestampCmsVerifier {
  // MARK: Static Functions

  /// TBS fields before the extensions: signature, issuer, validity,
  /// subject and SubjectPublicKeyInfo.
  private static let issuedNameFieldCount = 5

  /// Matches either CMS SignerIdentifier form to an embedded certificate.
  internal static func identifier(
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
  internal static func subjectKeyIdentifier(in certificate: Data) -> Data? {
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
    for _ in 0..<Self.issuedNameFieldCount {
      guard fields.next() != nil else { return nil }
    }
    while let candidate = fields.next() {
      guard candidate.tag == DerValues.tagContext3Constructed else { continue }
      return Self.keyIdentifier(in: candidate, certificate: certificate)
    }
    return nil
  }

  /// The content octets of the first id-ce-subjectKeyIdentifier found in
  /// one explicit extensions block, if the block carries the extension.
  private static func keyIdentifier(
    in candidate: DerReader.Element,
    certificate: Data
  ) -> Data? {
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

  private static func content(
    of element: DerReader.Element,
    in encoded: Data
  ) -> Data {
    let reader = DerReader(encoded)
    return reader.contentData(of: element)
  }
}
