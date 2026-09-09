// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The dedicated home for SCS wire values.
///
/// Source: the DVV SCS specification v1.3 (Signature Creation Service),
/// the localhost signing interface Finnish web services call at
/// `https://127.0.0.1:53952`. Protocol logic lives beside the other
/// card-facing protocol models; these are the named constants it
/// composes from.
internal enum ScsValues {
  /// The one TCP port the specification names (v1.3 §2.2).
  internal static let port: UInt16 = 53_952

  /// The protocol version this service implements and answers in
  /// every response body.
  internal static let version = "1.3"

  /// Smallest accepted authentication-challenge nonce, in octets
  /// (v1.3 §3.7).
  internal static let nonceMinimumLength = 64

  /// JWE initialization-vector length for A256GCM: 96 bits.
  internal static let jweInitializationVectorLength = 12

  /// JWE authentication-tag length for A256GCM: 128 bits.
  internal static let jweTagLength = 16

  /// Reason code: signature generated (v1.3 §2.6.3).
  internal static let reasonOk = 200

  /// Reason code: malformed request.
  internal static let reasonBadRequest = 400

  /// Reason code: end-user or credential refusal.
  internal static let reasonUnauthorized = 401

  /// Reason code: request refused by policy (origin or challenge
  /// binding).
  internal static let reasonForbidden = 403

  /// Reason code: internal failure.
  internal static let reasonInternalError = 500

  /// Reason code: valid request for an unimplemented capability.
  internal static let reasonNotImplemented = 501

  /// HTTP status: OK.
  ///
  /// The SCS answers 200 even for failed signs; the JSON reason
  /// triple carries the outcome (v1.3 §3).
  internal static let httpOk = 200

  /// HTTP status: no route.
  internal static let httpNotFound = 404

  /// Longest accepted HTTP head, in bytes; a longer one is not a
  /// well-formed SCS exchange.
  internal static let httpHeadMaximumLength = 65_536

  /// Longest accepted HTTP body, in bytes.
  ///
  /// Documents ride inline as base64, so the cap is generous but
  /// present.
  internal static let httpBodyMaximumLength = 16_777_216

  /// Compact JWS segment count: header, payload, signature.
  internal static let jwsSegmentCount = 3

  /// Compact JWS segment index of the signature.
  internal static let jwsSignatureIndex = 2

  /// Compact JWE segment count: header, empty key, IV, ciphertext,
  /// tag (direct encryption leaves the key segment empty).
  internal static let jweSegmentCount = 5

  /// Compact JWE segment index of the initialization vector.
  internal static let jweInitializationVectorIndex = 2

  /// Compact JWE segment index of the ciphertext.
  internal static let jweCiphertextIndex = 3

  /// Compact JWE segment index of the authentication tag.
  internal static let jweTagIndex = 4

  /// KeyUsage bits of the localhost server certificate:
  /// digitalSignature and keyEncipherment (v1.3 §2.3).
  internal static let serverKeyUsageBits: UInt8 = 0xA0

  /// Unused trailing bits in the KeyUsage BIT STRING above.
  internal static let serverKeyUsageUnusedBits: UInt8 = 5

  /// High octet of the IPv4 loopback address.
  private static let loopbackHighOctet: UInt8 = 0x7F

  /// The loopback address named in the certificate's
  /// subjectAltName (v1.3 §2.3): 127.0.0.1.
  internal static var loopbackAddress: [UInt8] {
    [Self.loopbackHighOctet, 0, 0, 1]
  }

  /// How long a generated localhost certificate stays valid; it is
  /// persisted and reused, so trust survives restarts.
  internal static let certificateValidityYears = 10
}
