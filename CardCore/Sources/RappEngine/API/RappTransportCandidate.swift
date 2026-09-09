// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One transport a published offer advertises.
public struct RappTransportCandidate: Equatable, Sendable {
  /// The transport profile this candidate implements.
  public var profile: String
  /// The identifier naming this candidate within the offer.
  public var candidateId: String
  /// The profile's public parameters, already deterministically encoded.
  public var parametersCbor: Data

  /// Advertises one transport.
  public init(profile: String, candidateId: String, parametersCbor: Data) {
    self.profile = profile
    self.candidateId = candidateId
    self.parametersCbor = parametersCbor
  }
}
