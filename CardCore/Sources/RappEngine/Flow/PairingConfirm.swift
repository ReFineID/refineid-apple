// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The explicit grant set one peer confirms.
internal struct PairingConfirm: Equatable {
  internal var grantedProfiles: [ProfileName]

  internal static func from(body: [String: WireValue]) throws -> Self {
    var fields = body
    guard case .array(let names)? = fields.removeValue(forKey: "granted_profiles") else {
      throw MessageFieldError.invalidField("granted_profiles")
    }
    guard fields.isEmpty else { throw MessageFieldError.invalidField("body") }
    return Self(grantedProfiles: try names.map(profileName))
  }

  internal func body() throws -> [String: WireValue] {
    try validateProfileSet(grantedProfiles)
    return ["granted_profiles": .array(grantedProfiles.map { .text($0.rawValue) })]
  }
}
