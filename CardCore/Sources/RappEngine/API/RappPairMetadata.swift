// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

// Absent and empty are different bytes on the wire, so the optionality is
// the protocol's own and not a convenience.
// swiftlint:disable discouraged_optional_collection

/// What a stored pairing says about itself, without its keys.
public struct RappPairMetadata: Equatable, Sendable {
  /// The identifier the pairing is stored under.
  public var pairId: Data
  /// Which side of the pairing this endpoint is.
  public var role: RappEndpointRole
  /// The credential profiles both endpoints granted.
  public var profiles: [String]
  /// The transport profile the pairing is bound to.
  public var transportProfile: String
  /// The transport candidate the pairing is bound to.
  public var candidateId: String
  /// The token naming this pairing to a dialing proxy.
  public var rendezvousToken: Data
  /// The listener endpoints, when the transport carries them.
  public var streamEndpoints: [String]?
  /// When the pairing was created.
  public var createdAtMs: UInt64

  /// Describes a stored pairing.
  public init(
    pairId: Data,
    role: RappEndpointRole,
    profiles: [String],
    transportProfile: String,
    candidateId: String,
    rendezvousToken: Data,
    streamEndpoints: [String]?,
    createdAtMs: UInt64
  ) {
    self.pairId = pairId
    self.role = role
    self.profiles = profiles
    self.transportProfile = transportProfile
    self.candidateId = candidateId
    self.rendezvousToken = rendezvousToken
    self.streamEndpoints = streamEndpoints
    self.createdAtMs = createdAtMs
  }
}

// swiftlint:enable discouraged_optional_collection
