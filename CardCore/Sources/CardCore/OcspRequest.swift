// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The OCSP request for one certificate (RFC 6960, RFC 8954).
///
/// The CertID hashes are SHA-1 and that is not a weakness here: they
/// identify a certificate to a responder that indexes by exactly
/// those hashes, and identification is not authentication. The
/// algorithm carries explicit NULL parameters because field
/// responders match that form; an absent-parameters request is
/// answered "unknown" by some of them.
public enum OcspRequest {
  /// Random bytes in the nonce (RFC 9654 section 2.1).
  public static let nonceByteCount = 32

  /// The DER request for one certificate under one issuer.
  ///
  /// `issuerName` is the issuer's Name as encoded in the subject's
  /// certificate, `issuerKey` the issuer's subjectPublicKey bits, and
  /// `serial` the subject's serialNumber value octets - each copied,
  /// never re-encoded, because a responder compares hashes and exact
  /// integers.
  public static func encoded(
    issuerName: Data,
    issuerKey: Data,
    serial: Data,
    nonce: Data
  ) -> Data {
    let certId = DerEncoder.sequence([
      Self.sha1AlgorithmIdentifier(),
      DerEncoder.octetString(Data(Insecure.SHA1.hash(data: issuerName))),
      DerEncoder.octetString(Data(Insecure.SHA1.hash(data: issuerKey))),
      DerEncoder.tlv(DerValues.tagInteger, serial),
    ])
    let request = DerEncoder.sequence([DerEncoder.sequence([certId])])
    let nonceExtension = DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.ocspNonce),
      DerEncoder.octetString(DerEncoder.octetString(nonce)),
    ])
    let extensions = DerEncoder.tlv(
      DerValues.tagContext2Constructed,
      DerEncoder.sequence([nonceExtension])
    )
    let tbsRequest = DerEncoder.sequence([request, extensions])
    return DerEncoder.sequence([tbsRequest])
  }

  /// SHA-1 with explicit NULL parameters.
  private static func sha1AlgorithmIdentifier() -> Data {
    DerEncoder.sequence([
      DerEncoder.objectIdentifier(SignOids.sha1),
      DerEncoder.tlv(DerValues.tagNull, Data()),
    ])
  }
}
