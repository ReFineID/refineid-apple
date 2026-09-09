// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `execute` response payload, encrypted back to the caller (DVV
/// SCS specification v1.3 §2.7.3).
internal struct ScsExecuteResponseDocument: Codable {
  /// The protocol version.
  internal let version: String

  /// The composed algorithm name.
  internal let signatureAlgorithm: String

  /// The signature form that was produced.
  internal let signatureType: String

  /// Base64 of the signature or SignedData.
  internal let signature: String

  /// Base64 DER certificate chain, leaf first.
  internal let chain: [String]

  /// Always `ok`; a refused execute answers an error body instead.
  internal let status: String

  /// The specification reason code.
  internal let reasonCode: Int

  /// The human-readable reason.
  internal let reasonText: String
}
