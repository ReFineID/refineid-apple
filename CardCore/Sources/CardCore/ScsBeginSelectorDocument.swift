// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The `begin` payload's certificate selector; only the fields this
/// service acts on are read, the rest are accepted for protocol
/// compatibility while certificate selection remains local (DVV SCS
/// specification v1.3 §2.7.2).
internal struct ScsBeginSelectorDocument: Codable {
  /// Accepted key algorithms, lowercase (`rsa`, `ec`).
  internal let keyalgorithms: [String]

  /// Requested key usages, by their X.509 names.
  internal let keyusages: [String]

  /// Decodes with the specification's optionality.
  internal init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.keyalgorithms =
      try container.decodeIfPresent([String].self, forKey: .keyalgorithms) ?? []
    self.keyusages =
      try container.decodeIfPresent([String].self, forKey: .keyusages) ?? []
  }
}
