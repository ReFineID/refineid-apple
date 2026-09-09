// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// XAdES: the XML signature an ASiC-E container carries
/// (ETSI EN 319 132-1, ETSI EN 319 162-1, BDOC 2.1).
///
/// `QualifiedDocumentCms` signs octets. This signs a *document*, and
/// the difference is the whole problem. XML has more than one
/// serialisation for the same document - `<a/>` and `<a></a>`,
/// attributes in either order, a namespace declared here or three
/// levels up - so before a digest means anything the XML has to be
/// reduced to one form. That reduction is canonicalisation, and every
/// verifier does it independently. Ours has to land on the same octets
/// theirs does.
///
/// # Why there is no canonicaliser in this file
///
/// The usual shape is: build a DOM, serialise it, parse it back,
/// canonicalise, digest. That needs an XML parser, a namespace-aware
/// node model, and an implementation of Exclusive XML Canonicalization
/// - a few thousand lines whose only job is to undo the freedom the
/// serialiser just used.
///
/// This type removes the freedom instead. Every element it writes is
/// already in canonical form: never self-closed, attributes in
/// canonical order, namespace declarations repeated at each subtree
/// root that uses them, and text escaped by the canonicalisation rules
/// rather than the looser XML ones. Canonicalising this output is the
/// identity function, so the bytes can be digested where they stand.
///
/// The rules being satisfied, from Exclusive XML Canonicalization 1.0
/// and Canonical XML 1.0 section 2:
///
/// - UTF-8, no XML declaration inside a canonicalised subset.
/// - Empty elements as a start/end pair: `<a></a>`, never `<a/>`.
/// - Attributes sorted: namespace declarations first, then by
///   namespace URI and local name.
/// - Attribute values escape `&`, `<`, `"` and the three whitespace
///   characters - but *not* `>` and *not* `'`. Text escapes `&`, `<`,
///   `>` and carriage return. Escaping more than that is valid XML and
///   is still wrong: the canonicaliser would unescape it.
/// - Exclusive canonicalisation renders a namespace declaration on the
///   outermost element of the subset that visibly uses the prefix, and
///   nowhere below it. So a subtree that gets digested on its own must
///   carry its own declarations.
///
/// Every digest here is SHA-384, because that is the one digest the
/// card signs and the one the rest of this app's evidence chain
/// already speaks.
public enum XadesSignature {
  /// A signature with everything built except the signature value.
  public struct Plan: Sendable {
    /// `ds:SignedInfo` in canonical form, kept as written.
    private let signedInfoXml: String

    /// `xades:SignedProperties` in canonical form, kept as digested.
    ///
    /// Already folded into the signed info; kept because it has to be
    /// written out again, byte for byte, inside `ds:Object`.
    private let signedPropertiesXml: String

    /// The signer's certificate, for `ds:KeyInfo`.
    private let certificateDer: Data

    /// The octets the card must sign.
    ///
    /// `ds:SignedInfo` in its canonical form. The verifier will
    /// canonicalise its own copy and expect these same bytes; a
    /// re-serialisation, a reindent, or a stray XML declaration
    /// produces a signature over octets nobody else computes.
    public var signedInfo: Data { Data(signedInfoXml.utf8) }

    /// Remembers the two canonical subtrees and the signer.
    internal init(
      signedInfoXml: String,
      signedPropertiesXml: String,
      certificateDer: Data
    ) {
      self.signedInfoXml = signedInfoXml
      self.signedPropertiesXml = signedPropertiesXml
      self.certificateDer = certificateDer
    }

    /// The unsigned properties: timestamps and validation material.
    ///
    /// Unsigned, so ordinary XML rules apply: nothing digests this
    /// subtree, which is the whole reason a timestamp over the
    /// signature can live in it. Schema order is fixed: timestamps,
    /// then certificates, then revocation values, and inside those
    /// CRLs before OCSP responses (XAdES `RevocationValuesType`).
    private static func unsignedProperties(
      timestampTokens: [Data],
      material: PdfValidationStore.Material
    ) -> String {
      guard !timestampTokens.isEmpty || !material.isEmpty else { return "" }
      var out = "<xades:UnsignedProperties>\n"
      out += "<xades:UnsignedSignatureProperties>\n"
      for (index, token) in timestampTokens.enumerated() {
        out += #"<xades:SignatureTimeStamp "#
        out += #"Id="\#(signatureId)-TS-\#(index)">"# + "\n"
        // Which canonicalisation the verifier must apply before
        // digesting `ds:SignatureValue`. It has to name the one
        // actually used, or the verifier hashes different bytes.
        out += #"<ds:CanonicalizationMethod "#
        out += #"Algorithm="\#(canonicalizationExclusive)">"#
        out += "</ds:CanonicalizationMethod>\n"
        out += "<xades:EncapsulatedTimeStamp>"
        out += token.base64EncodedString()
        out += "</xades:EncapsulatedTimeStamp>\n"
        out += "</xades:SignatureTimeStamp>\n"
      }
      if !material.certificates.isEmpty {
        out += "<xades:CertificateValues>\n"
        for chainCertificate in material.certificates {
          out += "<xades:EncapsulatedX509Certificate>"
          out += chainCertificate.base64EncodedString()
          out += "</xades:EncapsulatedX509Certificate>\n"
        }
        out += "</xades:CertificateValues>\n"
      }
      if !material.revocationLists.isEmpty || !material.ocspResponses.isEmpty {
        out += "<xades:RevocationValues>\n"
        if !material.revocationLists.isEmpty {
          out += "<xades:CRLValues>\n"
          for list in material.revocationLists {
            out += "<xades:EncapsulatedCRLValue>"
            out += list.base64EncodedString()
            out += "</xades:EncapsulatedCRLValue>\n"
          }
          out += "</xades:CRLValues>\n"
        }
        if !material.ocspResponses.isEmpty {
          out += "<xades:OCSPValues>\n"
          for response in material.ocspResponses {
            out += "<xades:EncapsulatedOCSPValue>"
            out += response.base64EncodedString()
            out += "</xades:EncapsulatedOCSPValue>\n"
          }
          out += "</xades:OCSPValues>\n"
        }
        out += "</xades:RevocationValues>\n"
      }
      out += "</xades:UnsignedSignatureProperties>\n"
      out += "</xades:UnsignedProperties>\n"
      return out
    }

    /// Assembles `META-INF/signatures0.xml`.
    ///
    /// `xmlSignature` is the signature over `signedInfo` in the XML
    /// form (raw `r || s` for ECDSA, the modulus-wide block for RSA).
    /// Each timestamp token is an RFC 3161 token over
    /// `XadesSignature.timestampDigest` and becomes its own
    /// `xades:SignatureTimeStamp`; an empty array leaves the signature
    /// at baseline level B. `material` fills `CertificateValues` and
    /// `RevocationValues`, raising the level to LT.
    public func document(
      xmlSignature: Data,
      timestampTokens: [Data],
      material: PdfValidationStore.Material
    ) -> Data {
      var out = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
      // The container-level wrapper. Not canonicalised and not
      // digested - nothing signs it - so ordinary XML rules apply
      // from here down, except inside the two subtrees that are.
      out += #"<asic:XAdESSignatures xmlns:asic="\#(namespaceAsic)">"# + "\n"
      out += #"<ds:Signature xmlns:ds="\#(namespaceDsig)" "#
      out += #"Id="\#(signatureId)">"# + "\n"

      // Byte for byte as signed. Never rebuilt here.
      out += signedInfoXml + "\n"

      // Byte for byte as the timestamp digested it, whether or not one
      // was taken: one spelling of this element, always.
      out += XadesSignature.signatureValueElement(xmlSignature) + "\n"

      out += "<ds:KeyInfo>\n<ds:X509Data>\n"
      out += "<ds:X509Certificate>"
      out += certificateDer.base64EncodedString()
      out += "</ds:X509Certificate>\n"
      out += "</ds:X509Data>\n</ds:KeyInfo>\n"

      out += "<ds:Object>\n"
      out += #"<xades:QualifyingProperties xmlns:xades="\#(namespaceXades)" "#
      out += "Target=\"#\(signatureId)\">\n"
      // Byte for byte as digested by the second reference.
      out += signedPropertiesXml + "\n"
      out += Self.unsignedProperties(
        timestampTokens: timestampTokens,
        material: material
      )
      out += "</xades:QualifyingProperties>\n"
      out += "</ds:Object>\n"

      out += "</ds:Signature>\n"
      out += "</asic:XAdESSignatures>\n"
      return Data(out.utf8)
    }
  }

  /// XML digital signature namespace (RFC 3275).
  internal static let namespaceDsig = "http://www.w3.org/2000/09/xmldsig#"

  /// XAdES 1.3.2 namespace, the version ASiC-E and BDOC both name.
  internal static let namespaceXades = "http://uri.etsi.org/01903/v1.3.2#"

  /// ASiC namespace (EN 319 162-1).
  internal static let namespaceAsic = "http://uri.etsi.org/02918/v1.2.1#"

  /// SHA-384 digest method identifier (RFC 4051 section 2.1).
  internal static let digestMethodSha384 =
    "http://www.w3.org/2001/04/xmldsig-more#sha384"

  /// Exclusive canonicalisation, without comments.
  internal static let canonicalizationExclusive =
    "http://www.w3.org/2001/10/xml-exc-c14n#"

  /// `Type` marking the reference that covers the signed properties.
  ///
  /// Note the namespace has no minor version: `01903#SignedProperties`,
  /// not `01903/v1.3.2#`. It is a fixed string in EN 319 132-1, and
  /// verifiers match it literally.
  internal static let signedPropertiesType =
    "http://uri.etsi.org/01903#SignedProperties"

  /// Identifier of the one signature this type writes.
  internal static let signatureId = "SIG-1"

  /// Identifier of its `SignedProperties`, the target of the second
  /// reference.
  internal static let signedPropertiesId = "SIG-1-SIGNEDPROPS"

  /// Identifier of the `SignatureValue`, which XAdES timestamps refer
  /// to when a signature is raised to a long-term level.
  internal static let signatureValueId = "SIG-1-SIGVAL"

  /// Builds the signature over `objects` and returns the plan to sign
  /// it.
  ///
  /// `signedAt` becomes the mandatory `SigningTime`
  /// (EN 319 132-1 section 5.2.1), written in UTC. Nil when `objects`
  /// is empty: a signature over nothing verifies happily and attests
  /// nothing.
  public static func plan(
    objects: [AsicContainer.DataObject],
    certificate: Data,
    profile: CardKeyProfile,
    signedAt: Date
  ) -> Plan? {
    guard !objects.isEmpty else { return nil }
    let properties = Self.signedProperties(
      objects: objects,
      certificate: certificate,
      signedAt: signedAt
    )
    let propertiesDigest = Data(SHA384.hash(data: Data(properties.utf8)))
    let info = Self.signedInfo(
      objects: objects,
      profile: profile,
      propertiesDigest: propertiesDigest
    )
    return Plan(
      signedInfoXml: info,
      signedPropertiesXml: properties,
      certificateDer: certificate
    )
  }

  /// The `ds:SignatureValue` element, in canonical form.
  ///
  /// This is what a `SignatureTimeStamp` is computed over -
  /// EN 319 132-1 section 5.2.3.1 timestamps the canonicalised
  /// *element*, tags and all, not the signature octets and not the
  /// base64 text. Digesting the raw signature instead produces a token
  /// that attests something appearing nowhere in the document.
  ///
  /// `xmlns:ds` is declared here, redundantly with the enclosing
  /// `ds:Signature`: a subtree digested on its own is canonicalised
  /// with no ancestors in scope, so it has to carry the declaration it
  /// uses. Attributes follow canonical order - the namespace
  /// declaration, then `Id`.
  public static func signatureValueElement(_ xmlSignature: Data) -> String {
    #"<ds:SignatureValue xmlns:ds="\#(namespaceDsig)" "#
      + #"Id="\#(signatureValueId)">"#
      + xmlSignature.base64EncodedString()
      + "</ds:SignatureValue>"
  }

  /// Digest of `signatureValueElement`, for a timestamp authority.
  public static func timestampDigest(_ xmlSignature: Data) -> Data {
    Data(SHA384.hash(data: Data(Self.signatureValueElement(xmlSignature).utf8)))
  }
}
