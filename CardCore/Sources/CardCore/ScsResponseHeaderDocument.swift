// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The signed response JWT's protected header (DVV SCS specification
/// v1.3 §2.7.2).
internal struct ScsResponseHeaderDocument: Codable {
  /// The JWS algorithm name.
  internal let alg: String

  /// The signing certificate's key identifier.
  internal let kid: String

  /// Always `JWT`.
  internal let typ: String
}
