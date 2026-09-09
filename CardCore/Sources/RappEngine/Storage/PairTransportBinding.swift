// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Transport this pairing is bound to.
internal struct PairTransportBinding: Equatable {
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
  /// A binding whose candidate carries no parameters.
  internal init(profile: String, candidateIdentifier: String) {
    self.init(profile: profile, candidateIdentifier: candidateIdentifier, parameters: [:])
  }
}
