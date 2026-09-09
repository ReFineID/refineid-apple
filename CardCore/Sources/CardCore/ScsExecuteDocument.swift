// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `execute` payload carried inside the JWE (DVV SCS
/// specification v1.3 §2.7.3).
internal struct ScsExecuteDocument: Codable {
  /// The protocol version of the transaction.
  internal let version: String

  /// Base64 of the content or digest to sign.
  internal let content: String

  /// `data` or `digest`; `data` when absent.
  internal let contentType: String

  /// The digest name; SHA256 when absent.
  internal let hashAlgorithm: String

  /// The key algorithm name; RSA when absent.
  internal let signatureAlgorithm: String

  /// `signature` or `cms-pades`; `signature` when absent.
  internal let signatureType: String

  /// Decodes with the specification's optionality.
  internal init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.version = try container.decode(String.self, forKey: .version)
    self.content = try container.decode(String.self, forKey: .content)
    self.contentType =
      try container.decodeIfPresent(String.self, forKey: .contentType) ?? "data"
    self.hashAlgorithm =
      try container.decodeIfPresent(String.self, forKey: .hashAlgorithm) ?? "SHA256"
    self.signatureAlgorithm =
      try container.decodeIfPresent(String.self, forKey: .signatureAlgorithm) ?? "RSA"
    self.signatureType =
      try container.decodeIfPresent(String.self, forKey: .signatureType) ?? "signature"
  }
}
