// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The certificates carried inside a CMS SignedData (RFC 5652 §5.1).
///
/// A timestamp token embeds the authority's certificate and its chain,
/// because the request asked for them. A validator needs revocation
/// evidence for those as well as for the signer, so the signing side
/// has to be able to read them back out of the token it just received.
public enum CmsCertificates {
  /// The SignedData fields needed to inspect or remove its CertificateSet.
  private struct Layout {
    let contentType: Data
    let signedData: DerReader.Element
    let certificates: DerReader.Element?
  }

  /// Every certificate in the token's `certificates [0]` field, in the
  /// order written, or an empty array when there are none.
  public static func inside(_ token: Data) -> [Data] {
    guard
      let layout = Self.layout(in: token),
      let certificateSet = layout.certificates
    else { return [] }
    var list = DerReader(token, within: certificateSet)
    var certificates: [Data] = []
    while let element = list.next() {
      // Only plain certificates; the other choices are attribute
      // certificates a validator does not want here.
      guard element.tag == DerValues.tagSequence else { continue }
      certificates.append(list.data(of: element))
    }
    return list.isAtEnd ? certificates : []
  }

  /// Removes only SignedData's optional CertificateSet.
  ///
  /// SignerInfo does not cover this field, so a token verified before this
  /// operation keeps the same signed TSTInfo, attributes and signature. The
  /// enclosing lengths are rebuilt because the token becomes smaller.
  public static func removingCertificates(from token: Data) -> Data? {
    let encoded = Data(token)
    guard
      let layout = Self.layout(in: encoded),
      let certificateSet = layout.certificates
    else { return nil }
    var body = Data(
      encoded[
        layout.signedData.content.lowerBound..<certificateSet.raw.lowerBound
      ]
    )
    body.append(
      encoded[
        certificateSet.raw.upperBound..<layout.signedData.content.upperBound
      ]
    )
    let signedData = DerEncoder.tlv(DerValues.tagSequence, body)
    return DerEncoder.sequence([
      layout.contentType,
      DerEncoder.tlv(DerValues.tagContext0Constructed, signedData),
    ])
  }

  /// Parses one complete SignedData and locates its optional CertificateSet.
  private static func layout(in token: Data) -> Layout? {
    guard let content = Self.signedData(in: token) else { return nil }
    var reader = DerReader(token, within: content.element)
    // version, digestAlgorithms, encapContentInfo, then optional fields.
    guard
      let version = reader.next(),
      version.tag == DerValues.tagInteger,
      let algorithms = reader.next(),
      algorithms.tag == DerValues.tagSet,
      let encapsulated = reader.next(),
      encapsulated.tag == DerValues.tagSequence,
      var candidate = reader.next()
    else {
      return nil
    }
    let certificates: DerReader.Element?
    if candidate.tag == DerValues.tagContext0Constructed {
      certificates = candidate
      guard let following = reader.next() else { return nil }
      candidate = following
    } else {
      certificates = nil
    }
    if candidate.tag == DerValues.tagContext1Constructed {
      guard let following = reader.next() else { return nil }
      candidate = following
    }
    guard candidate.tag == DerValues.tagSet, reader.isAtEnd else { return nil }
    return Layout(
      contentType: content.contentType,
      signedData: content.element,
      certificates: certificates
    )
  }

  /// The inner SignedData and the ContentInfo type that named it.
  private static func signedData(
    in token: Data
  ) -> (contentType: Data, element: DerReader.Element)? {
    var outer = DerReader(token)
    guard
      let contentInfo = outer.next(),
      contentInfo.tag == DerValues.tagSequence,
      outer.isAtEnd
    else { return nil }
    var info = DerReader(token, within: contentInfo)
    guard
      let contentType = info.next(),
      info.data(of: contentType)
        == DerEncoder.objectIdentifier(SignOids.signedData),
      let explicitWrap = info.next(),
      explicitWrap.tag == DerValues.tagContext0Constructed,
      info.isAtEnd
    else {
      return nil
    }
    var wrapped = DerReader(token, within: explicitWrap)
    guard
      let signedData = wrapped.next(),
      signedData.tag == DerValues.tagSequence,
      wrapped.isAtEnd
    else { return nil }
    return (info.data(of: contentType), signedData)
  }
}
