// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One profile checked against a grant set.
internal struct GrantEnforcementVector: Decodable {
  private enum CodingKeys: String, CodingKey {
    case expected = "expected"
    case grantedProfiles = "granted_profiles"
    case name = "name"
    case requestedProfile = "requested_profile"
  }

  internal let name: String
  internal let grantedProfiles: [String]
  internal let requestedProfile: String
  internal let expected: String
}
