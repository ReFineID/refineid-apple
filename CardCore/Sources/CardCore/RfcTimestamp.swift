// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// RFC 3161 request construction and response binding checks.
///
/// The HTTP exchange and certificate trust decision belong to the
/// caller. This layer parses the TimeStampResp and proves that its
/// TSTInfo names SHA-384, carries the requested imprint and nonce, and
/// has a usable generation time. `TimestampTokenVerifier` performs the
/// CMS signature and signer-certificate checks before a token is used.
public enum RfcTimestamp {
  /// A refused or unusable timestamp answer.
  public enum TokenFailure: Error, Equatable {
    /// The token names a message-imprint algorithm other than the one
    /// requested.
    case imprintAlgorithmMismatch

    /// The token's imprint is not the digest that was sent.
    case imprintMismatch

    /// The response did not parse as a TimeStampResp with a token.
    case malformed

    /// The token's nonce is absent or not the one sent.
    case nonceMismatch

    /// The authority answered with a non-granted status.
    case rejected(status: Int)
  }

  /// Parsed content shared with the platform signature verifier.
  internal struct TokenContents {
    /// The encapsulated TSTInfo octets.
    internal let tstInfo: Data

    /// The time claimed by that signed TSTInfo.
    internal let generatedAt: Date
  }

  /// SHA-384 output size in octets.
  private static let sha384DigestByteCount = 48

  /// The TimeStampReq: version 1, the SHA-384 imprint, a nonce, and an
  /// explicit request for the signing certificate.
  public static func request(digest: Data, nonceBytes: Data) -> Data {
    Self.request(
      digest: digest, nonceBytes: nonceBytes, askingForCertificate: true
    )
  }

  /// The same, able to leave the authority's certificate out.
  ///
  /// A token carrying the authority's certificate is some four and a
  /// half kilobytes; without it, thirteen hundred bytes. That is the
  /// difference between fitting in a printed code and not. Archival
  /// signatures always ask for it - their validation data needs the
  /// chain - so only a token bound for somewhere small asks without.
  public static func request(
    digest: Data,
    nonceBytes: Data,
    askingForCertificate: Bool
  ) -> Data {
    var fields: [Data] = [
      DerEncoder.integer(SignOids.timestampRequestVersion),
      DerEncoder.sequence([
        DerEncoder.sequence([DerEncoder.objectIdentifier(SignOids.sha384)]),
        DerEncoder.octetString(digest),
      ]),
      DerEncoder.unsignedInteger(nonceBytes),
    ]
    if askingForCertificate {
      fields.append(DerEncoder.booleanTrue())
    }
    return DerEncoder.sequence(fields)
  }

  /// The checked TimeStampToken out of a TimeStampResp, verbatim.
  public static func token(
    fromResponse response: Data,
    digest: Data,
    nonceBytes: Data
  ) throws -> Data {
    guard digest.count == Self.sha384DigestByteCount else {
      throw TokenFailure.malformed
    }
    let encoded = try Self.encodedToken(inResponse: response)
    let contents = try Self.contents(in: encoded)
    let binding = try Self.binding(in: contents.tstInfo)
    guard Self.isSha384(binding.algorithm) else {
      throw TokenFailure.imprintAlgorithmMismatch
    }
    guard binding.digest.count == Self.sha384DigestByteCount else {
      throw TokenFailure.malformed
    }
    guard binding.digest == digest else {
      throw TokenFailure.imprintMismatch
    }
    guard binding.nonce == DerEncoder.unsignedInteger(nonceBytes) else {
      throw TokenFailure.nonceMismatch
    }
    return encoded
  }

  /// The generation time carried by a token's TSTInfo.
  ///
  /// This is a parsed claim until `TimestampTokenVerifier` verifies the
  /// token's CMS signature.
  public static func generationTime(in token: Data) throws -> Date {
    try Self.contents(in: token).generatedAt
  }

  /// The encapsulated TSTInfo and its generation time.
  internal static func contents(in token: Data) throws -> TokenContents {
    let tstInfo = try Self.tstInfoContent(in: token)
    let binding = try Self.binding(in: tstInfo)
    return TokenContents(tstInfo: tstInfo, generatedAt: binding.generatedAt)
  }
}
