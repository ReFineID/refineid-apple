// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Public rendezvous candidate an offer advertises.
internal struct TransportCandidate: Equatable, Sendable {
  internal var profile: String
  internal var candidateIdentifier: String
  internal var parameters: [String: WireValue]

  internal init(
    profile: String,
    candidateIdentifier: String,
    parameters: [String: WireValue]
  ) {
    self.profile = profile
    self.candidateIdentifier = candidateIdentifier
    self.parameters = parameters
  }
  /// A candidate that carries no parameters.
  internal init(profile: String, candidateIdentifier: String) {
    self.init(profile: profile, candidateIdentifier: candidateIdentifier, parameters: [:])
  }
}
