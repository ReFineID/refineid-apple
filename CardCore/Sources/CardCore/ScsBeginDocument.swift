// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `begin` payload: the relying service's key, certificate, and
/// certificate selector (DVV SCS specification v1.3 §2.7.2).
internal struct ScsBeginDocument: Codable {
  /// The protocol version of the transaction.
  internal let version: String

  /// Base64 DER SPKI of the service's P-256 agreement key.
  internal let serverKey: String

  /// Base64 DER certificate authorising the transaction.
  internal let serverCert: String

  /// Whether the key-algorithm selector is binding; false when
  /// absent.
  internal let strictKeyPolicy: Bool

  /// The certificate selector, when sent.
  internal let selector: ScsBeginSelectorDocument?

  /// Decodes with the specification's optionality.
  internal init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try container.decode(String.self, forKey: .version)
    self.serverKey = try container.decode(String.self, forKey: .serverKey)
    self.serverCert = try container.decode(String.self, forKey: .serverCert)
    self.strictKeyPolicy =
      try container.decodeIfPresent(Bool.self, forKey: .strictKeyPolicy) ?? false
    self.selector = try container.decodeIfPresent(
      ScsBeginSelectorDocument.self, forKey: .selector)
  }
}
