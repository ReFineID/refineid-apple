// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `begin` response payload this service signs (DVV SCS
/// specification v1.3 §2.7.2).
internal struct ScsBeginResponseDocument: Codable {
  /// The protocol version.
  internal let version: String

  /// Base64 DER SPKI of this service's ephemeral agreement key.
  internal let transaction: String

  /// Base64 DER certificate chain, leaf first.
  internal let chain: [String]

  /// Always `ok`; a refused begin answers an error body instead.
  internal let status: String

  /// The specification reason code.
  internal let reasonCode: Int

  /// The human-readable reason.
  internal let reasonText: String
}
