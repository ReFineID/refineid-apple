// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Minimal detached CMS SignedData for the SCS `cms-pades` form.
///
/// The caller supplies the document digest; the card signs the DER
/// SET of signed attributes (content-type and message-digest, RFC
/// 5652 section 5.4), and the finished SignedData carries the
/// certificate chain and the signature with the content itself
/// detached - the PAdES shape a signing service embeds into the
/// document (DVV SCS specification v1.3 §2.6.2).
public struct ScsDetachedCms {
  private let certificates: [Data]
  private let issuerName: Data
  private let serialNumber: Data
  private let digestOid: String

  /// The DER SET of signed attributes: the exact bytes the card
  /// signs.
  public let signedAttributes: Data

  /// Prepares the attribute set for `digest` under `hashName`.
  ///
  /// Refuses a digest whose length does not match the named hash,
  /// and an empty chain - the leaf supplies the signer identifier.
  public static func prepare(
    digest: Data,
    certificates: [Data],
    hashName: String
  ) -> Result<Self, ScsTransactionError> {
    guard let hash = ScsKeyAlgorithm.hash(named: hashName) else {
      return .failure(.badRequest("unsupported CMS digest algorithm \(hashName)"))
    }
    guard digest.count == hash.digestByteCount else {
      return .failure(
        .badRequest(
          "\(hashName) digest must be \(hash.digestByteCount) bytes, got \(digest.count)"))
    }
    guard
      let leaf = certificates.first,
      let facts = CertificateFacts(der: leaf)
    else {
      return .failure(.badRequest("leaf certificate is not DER X.509"))
    }
    let algorithmOid =
      switch hash {
      case .sha1:
        SignOids.sha1

      case .sha224, .sha256:
        SignOids.sha256

      case .sha384:
        SignOids.sha384

      case .sha512:
        SignOids.sha512
      }
    let attributes = DerEncoder.setOf([
      DerEncoder.sequence([
        DerEncoder.objectIdentifier(SignOids.contentType),
        DerEncoder.setOf([DerEncoder.objectIdentifier(SignOids.data)]),
      ]),
      DerEncoder.sequence([
        DerEncoder.objectIdentifier(SignOids.messageDigest),
        DerEncoder.setOf([DerEncoder.octetString(digest)]),
      ]),
    ])
    return .success(
      Self(
        certificates: certificates,
        issuerName: facts.issuerName,
        serialNumber: facts.serialNumber,
        digestOid: algorithmOid,
        signedAttributes: attributes
      )
    )
  }

  /// Assembles the finished SignedData around the card's signature
  /// over `signedAttributes`.
  public func signedData(signature: Data) -> Data {
    let digestAlgorithm = DerEncoder.sequence([
      DerEncoder.objectIdentifier(digestOid),
      DerEncoder.null(),
    ])
    let signerIdentifier = DerEncoder.sequence([
      issuerName,
      DerEncoder.unsignedInteger(serialNumber),
    ])
    let signerInfo = DerEncoder.sequence([
      DerEncoder.integer(SignOids.signerInfoVersion),
      signerIdentifier,
      digestAlgorithm,
      DerEncoder.retagged(signedAttributes, to: DerValues.tagContext0Constructed),
      digestAlgorithm,
      DerEncoder.octetString(signature),
    ])
    let content = DerEncoder.sequence([
      DerEncoder.integer(SignOids.cmsVersion),
      DerEncoder.setOf([digestAlgorithm]),
      DerEncoder.sequence([DerEncoder.objectIdentifier(SignOids.data)]),
      DerEncoder.tlv(
        DerValues.tagContext0Constructed,
        certificates.reduce(Data(), +)
      ),
      DerEncoder.setOf([signerInfo]),
    ])
    return DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.signedData),
      DerEncoder.tlv(DerValues.tagContext0Constructed, content),
    ])
  }
}
