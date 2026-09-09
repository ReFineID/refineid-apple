// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension SigningNetwork {
  /// Why the caller is contacting one endpoint.
  ///
  /// Timestamp authorities are configured by the user. Certificate
  /// material addresses are copied from an untrusted certificate and
  /// therefore must resolve only to public addresses.
  internal enum Endpoint: Sendable {
    case authority
    case certificateMaterial
  }

  /// The pure outcome of one redirect-policy decision.
  internal enum RedirectDecision: Equatable {
    case follow
    case refuse
  }
}
