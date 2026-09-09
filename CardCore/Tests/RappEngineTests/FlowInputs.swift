// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The values fixed when the flow bodies were captured, recorded beside them
/// so the Swift engine builds from identical inputs.
internal struct FlowInputs: Decodable {
  private enum CodingKeys: String, CodingKey {
    case offerHashHex = "offer_hash_hex"
    case grantsHashFixedHex = "grants_hash_fixed_hex"
    case grantsHashDerivedHex = "grants_hash_derived_hex"
    case readyNonceHex = "ready_nonce_hex"
    case transportProfile = "transport_profile"
    case candidateIdentifier = "candidate_id"
    case requesterDisplayName = "requester_display_name"
    case requesterPlatform = "requester_platform"
    case proxyDisplayName = "proxy_display_name"
    case proxyPlatform = "proxy_platform"
    case offeredProfiles = "offered_profiles"
  }

  internal let offerHashHex: String
  internal let grantsHashFixedHex: String
  internal let grantsHashDerivedHex: String
  internal let readyNonceHex: String
  internal let transportProfile: String
  internal let candidateIdentifier: String
  internal let requesterDisplayName: String
  internal let requesterPlatform: String
  internal let proxyDisplayName: String
  internal let proxyPlatform: String
  internal let offeredProfiles: [String]
}
