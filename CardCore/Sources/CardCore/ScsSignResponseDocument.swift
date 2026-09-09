// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `/sign` response document (DVV SCS specification v1.3 §2.6.3).
///
/// HTTP status is always 200; the `status` / `reasonCode` /
/// `reasonText` triple carries the actual outcome so the calling
/// page's error path renders properly. The signature fields are
/// omitted - not nulled - on failure, as the specification's
/// examples print.
public struct ScsSignResponseDocument: Codable, Equatable, Sendable {
  /// The protocol version.
  public let version: String

  /// `ok` or `failed`.
  public let status: String

  /// The specification reason code.
  public let reasonCode: Int

  /// The human-readable reason.
  public let reasonText: String

  /// Base64 signature on success.
  public let signature: String?

  /// The signature form on success; this service answers raw
  /// `signature` values on the JSON path.
  public let signatureType: String?

  /// The composed algorithm name on success.
  public let signatureAlgorithm: String?

  /// Base64 DER certificate chain on success, leaf first; empty on
  /// failure and then omitted from the encoding.
  public let chain: [String]

  /// A successful response.
  public static func ok(
    signature: String,
    signatureAlgorithm: String,
    chain: [String]
  ) -> Self {
    Self(
      version: ScsValues.version,
      status: "ok",
      reasonCode: ScsValues.reasonOk,
      reasonText: "OK: Signature generated",
      signature: signature,
      signatureType: "signature",
      signatureAlgorithm: signatureAlgorithm,
      chain: chain
    )
  }

  /// A refused response carrying the specification reason.
  public static func failed(reasonCode: Int, reasonText: String) -> Self {
    Self(
      version: ScsValues.version,
      status: "failed",
      reasonCode: reasonCode,
      reasonText: reasonText,
      signature: nil,
      signatureType: nil,
      signatureAlgorithm: nil,
      chain: []
    )
  }

  /// Encodes with the success-only fields omitted when absent.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(version, forKey: .version)
    try container.encode(status, forKey: .status)
    try container.encode(reasonCode, forKey: .reasonCode)
    try container.encode(reasonText, forKey: .reasonText)
    try container.encodeIfPresent(signature, forKey: .signature)
    try container.encodeIfPresent(signatureType, forKey: .signatureType)
    try container.encodeIfPresent(signatureAlgorithm, forKey: .signatureAlgorithm)
    if !chain.isEmpty {
      try container.encode(chain, forKey: .chain)
    }
  }
}
