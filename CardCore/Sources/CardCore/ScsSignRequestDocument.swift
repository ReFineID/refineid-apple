// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `/sign` request document (DVV SCS specification v1.3 §2.6.2).
///
/// `content` is base64 of either the raw data to sign
/// (`contentType == "data"`) or a pre-computed digest
/// (`contentType == "digest"`). The selector's key usages pick the
/// card key: `nonRepudiation` selects the qualified key, anything
/// else the authentication key.
public struct ScsSignRequestDocument: Codable, Equatable, Sendable {
  /// The selector object narrowing which certificate may sign.
  public struct Selector: Codable, Equatable, Sendable {
    /// Requested key usages, by their X.509 names; empty when the
    /// caller sent none.
    public let keyusages: [String]

    /// Builds a selector for tests and local callers.
    public init(keyusages: [String]) {
      self.keyusages = keyusages
    }

    /// Decodes with the specification's optionality.
    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyusages =
        try container.decodeIfPresent([String].self, forKey: .keyusages) ?? []
    }
  }

  /// Base64 of the data or digest to sign.
  public let content: String

  /// `data` or `digest`.
  public let contentType: String

  /// The certificate selector, when the caller sent one.
  public let selector: Selector?

  /// The requested digest name, when the caller sent one.
  public let hashAlgorithm: String?

  /// The requested signature form, when the caller sent one.
  public let signatureType: String?

  /// The card key this request selects.
  public var purpose: ScsSignPurpose {
    let qualified = selector?.keyusages.contains { usage in
      usage.caseInsensitiveCompare("nonRepudiation") == .orderedSame
    }
    return qualified == true ? .qualified : .authentication
  }

  /// Builds a request document for tests and local callers.
  public init(
    content: String,
    contentType: String,
    selector: Selector?,
    hashAlgorithm: String?,
    signatureType: String?
  ) {
    self.content = content
    self.contentType = contentType
    self.selector = selector
    self.hashAlgorithm = hashAlgorithm
    self.signatureType = signatureType
  }
}
