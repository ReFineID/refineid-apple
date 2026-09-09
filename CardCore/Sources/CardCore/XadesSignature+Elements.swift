// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The two canonical subtrees a signature is built from.
extension XadesSignature {
  /// Writes `ds:SignedInfo` in canonical form.
  ///
  /// `xmlns:ds` is declared here even though the enclosing
  /// `ds:Signature` also declares it. Under exclusive canonicalisation
  /// this element is digested as a subset of its own, with no
  /// ancestors in scope, so the declaration it visibly uses has to
  /// appear on it. Removing the apparent redundancy breaks every
  /// verifier. Attributes are written in canonical order: `Id`, then
  /// `Type`, then `URI`.
  internal static func signedInfo(
    objects: [AsicContainer.DataObject],
    profile: CardKeyProfile,
    propertiesDigest: Data
  ) -> String {
    var out = #"<ds:SignedInfo xmlns:ds="\#(namespaceDsig)">"# + "\n"
    out += #"<ds:CanonicalizationMethod "#
    out += #"Algorithm="\#(canonicalizationExclusive)">"#
    out += "</ds:CanonicalizationMethod>\n"
    out += #"<ds:SignatureMethod "#
    out += #"Algorithm="\#(Self.signatureMethod(profile))">"#
    out += "</ds:SignatureMethod>\n"

    // One reference per file. The URI is the entry name, resolved
    // against the container root rather than against the directory the
    // signature sits in (EN 319 162-1 annex A.4). So a file at the top
    // of the archive is named plainly here, even though this document
    // lives under `META-INF/`.
    for (index, object) in objects.enumerated() {
      let uri = Self.escapeAttribute(Self.percentEncodePath(object.name))
      let digest = Data(SHA384.hash(data: object.content))
        .base64EncodedString()
      out += #"<ds:Reference Id="\#(Self.referenceId(index))" "#
      out += #"URI="\#(uri)">"# + "\n"
      out += #"<ds:DigestMethod Algorithm="\#(digestMethodSha384)">"#
      out += "</ds:DigestMethod>\n"
      out += "<ds:DigestValue>\(digest)</ds:DigestValue>\n"
      out += "</ds:Reference>\n"
    }

    // The reference that makes this XAdES rather than bare XML-DSig:
    // it pulls the signed properties - signing time, signing
    // certificate - under the same signature as the files.
    //
    // The transform is not decoration. A same-document reference
    // yields a node set, and XML-DSig canonicalises a node set with
    // *inclusive* C14N when no transform says otherwise. Inclusive
    // would drag in the ancestors' namespace declarations, and the
    // digest would not match the octets written below. Naming
    // exclusive canonicalisation here is what makes the subtree
    // digestible on its own.
    out += #"<ds:Reference Id="\#(signatureId)-REF-SP" "#
    out += #"Type="\#(signedPropertiesType)" "#
    out += "URI=\"#\(signedPropertiesId)\">\n"
    out += "<ds:Transforms>\n"
    out += #"<ds:Transform Algorithm="\#(canonicalizationExclusive)">"#
    out += "</ds:Transform>\n"
    out += "</ds:Transforms>\n"
    out += #"<ds:DigestMethod Algorithm="\#(digestMethodSha384)">"#
    out += "</ds:DigestMethod>\n"
    out += "<ds:DigestValue>"
    out += propertiesDigest.base64EncodedString()
    out += "</ds:DigestValue>\n"
    out += "</ds:Reference>\n"

    out += "</ds:SignedInfo>"
    return out
  }

  /// Writes `xades:SignedProperties` in canonical form.
  ///
  /// Two prefixes appear, and they are declared at different depths
  /// for the same reason. `xades` is used by this element, so
  /// exclusive canonicalisation renders it here. `ds` is used only by
  /// the two digest elements inside `CertDigest`, and their ancestors
  /// do not use it, so the declaration is rendered on each of those
  /// two elements individually - not on a common parent, which would
  /// never have been asked to declare it.
  internal static func signedProperties(
    objects: [AsicContainer.DataObject],
    certificate: Data,
    signedAt: Date
  ) -> String {
    let certificateDigest = Data(SHA384.hash(data: certificate))
      .base64EncodedString()

    var out = #"<xades:SignedProperties xmlns:xades="\#(namespaceXades)" "#
    out += #"Id="\#(signedPropertiesId)">"# + "\n"
    out += "<xades:SignedSignatureProperties>\n"
    out += "<xades:SigningTime>"
    out += Self.dateTime(signedAt)
    out += "</xades:SigningTime>\n"

    // The XML spelling of the CAdES signing-certificate-v2 attribute,
    // and mandatory for the same reason: without it a signature can be
    // replayed against another certificate carrying the same key.
    //
    // `IssuerSerialV2` is optional and omitted: the digest already
    // pins the certificate uniquely, and a second, weaker identifier
    // only creates a way for the two to disagree.
    out += "<xades:SigningCertificateV2>\n<xades:Cert>\n<xades:CertDigest>\n"
    out += #"<ds:DigestMethod xmlns:ds="\#(namespaceDsig)" "#
    out += #"Algorithm="\#(digestMethodSha384)">"#
    out += "</ds:DigestMethod>\n"
    out += #"<ds:DigestValue xmlns:ds="\#(namespaceDsig)">"#
    out += certificateDigest
    out += "</ds:DigestValue>\n"
    out += "</xades:CertDigest>\n</xades:Cert>\n</xades:SigningCertificateV2>\n"
    out += "</xades:SignedSignatureProperties>\n"

    // Each file's media type, signed rather than left to the container
    // to assert. BDOC 2.1 section 6.3 requires one entry per
    // reference.
    out += "<xades:SignedDataObjectProperties>\n"
    for (index, object) in objects.enumerated() {
      out += "<xades:DataObjectFormat "
      out += "ObjectReference=\"#\(Self.referenceId(index))\">\n"
      out += "<xades:MimeType>"
      out += Self.escapeText(object.mimeType)
      out += "</xades:MimeType>\n"
      out += "</xades:DataObjectFormat>\n"
    }
    out += "</xades:SignedDataObjectProperties>\n"

    out += "</xades:SignedProperties>"
    return out
  }

  /// The `ds:Reference` identifier for the data object at `index`.
  internal static func referenceId(_ index: Int) -> String {
    "\(signatureId)-REF-\(index)"
  }
}
