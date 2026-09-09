// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The offered profiles, each registered, ordered by name bytes.
internal func parseOfferedProfiles(_ names: [String]) throws -> [ProfileName] {
  let profiles = try names.map { name -> ProfileName in
    guard let profile = ProfileName(rawValue: name) else {
      throw PairingError.unsupportedProfile
    }
    return profile
  }
  try validateGrants(profiles, offered: profiles)
  return sortedByNameBytes(profiles)
}

/// A grant set must be non-empty, free of duplicates, and drawn only from the
/// offered profiles.
internal func validateGrants(_ grants: [ProfileName], offered: [ProfileName]) throws {
  guard !grants.isEmpty,
    Set(grants.map(\.rawValue)).count == grants.count,
    grants.allSatisfy(offered.contains)
  else { throw PairingError.invalidGrantSet }
}

/// The profiles both sides can support, ordered for confirmation.
internal func grantIntersection(
  offered: [ProfileName], requested: [ProfileName]
) -> [ProfileName] {
  sortedByNameBytes(offered.filter(requested.contains))
}
