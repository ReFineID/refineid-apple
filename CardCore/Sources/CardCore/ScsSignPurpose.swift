// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Which card key an SCS request selects.
///
/// The request's selector names key usages; `nonRepudiation` selects
/// the qualified-signature key and everything else the authentication
/// key (DVV SCS specification v1.3 §2.6.2). The two keys carry
/// different obligations: an authentication signature must only ever
/// cover an origin-bound challenge, a qualified signature covers the
/// document the holder chose to sign.
public enum ScsSignPurpose: Equatable, Sendable {
  /// The PIN1-gated authentication key.
  case authentication

  /// The PIN2-gated qualified-signature key.
  case qualified
}
