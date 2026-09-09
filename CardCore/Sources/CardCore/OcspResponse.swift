// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Authenticates one OCSP response for one certificate and issuer.
///
/// A received OCSP body is not validation material merely because it
/// parses. RFC 6960 requires the exact CertID, a valid response signature,
/// the responder identity and authority, and a current validity interval.
/// This verifier makes all of those checks before returning `good` status.
public enum OcspResponse {
  /// Why an OCSP response cannot be relied upon.
  public enum ValidationFailure: Error, Equatable {
    /// No response identifies the exact certificate that was requested.
    case certificateMismatch

    /// The subject, issuer, or responder certificate did not parse.
    case certificateUnparseable

    /// The supplied issuer does not issue the certificate being checked.
    case issuerMismatch

    /// The response does not have the required DER structure.
    case malformed

    /// The caller supplied a nonce outside the RFC 9654 range.
    case nonceMalformed

    /// The echoed nonce does not equal the nonce sent in the request.
    case nonceMismatch

    /// The responder returned an OCSP error rather than a definitive answer.
    case rejected(status: Int)

    /// A delegated responder lacks `id-pkix-ocsp-nocheck`, and this
    /// verifier was not given independently authenticated revocation
    /// evidence for that responder certificate.
    case responderRevocationUnchecked

    /// The signer is neither the issuer nor an authorized delegated responder.
    case responderUnauthorized

    /// The ResponderID names no supplied issuer or embedded responder.
    case responderUnidentified

    /// `nextUpdate` is not after `thisUpdate`, or is already expired.
    case responseExpired

    /// `producedAt` or `thisUpdate` is later than the supplied current time.
    case responseFromFuture

    /// The answer reports that the target certificate is revoked.
    case revoked

    /// The response signature is absent, malformed, or does not verify.
    case signatureInvalid

    /// The responder has no status for the target certificate.
    case unknown

    /// An unsupported critical response extension was present.
    case unsupportedCriticalExtension

    /// The response type is not `id-pkix-ocsp-basic`.
    case unsupportedResponseType

    /// The response uses a signature algorithm this verifier does not support.
    case unsupportedSignatureAlgorithm
  }

  /// The authenticated facts returned for a current good response.
  public struct Validity: Equatable, Sendable {
    /// The time by which the responder says newer information is available.
    ///
    /// A response may omit this value, which RFC 6960 defines as newer
    /// information being available all the time.
    public let nextUpdate: Date?

    /// The time at which the responder signed the response.
    public let producedAt: Date

    /// The most recent time when the responder knew the status was correct.
    public let thisUpdate: Date
  }
}
