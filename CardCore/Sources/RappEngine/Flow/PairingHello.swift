// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

// The requested profiles are optional rather than empty on purpose: the
// asking side sends the field and the answering side omits it entirely, and
// the vendored bodies prove those are different bytes. An empty array would
// encode the field and no peer would read it as absent.
/// Authenticated peer introduction on the pairing channel.
///
/// Only the requester names the profiles it asks for, so the field's presence
/// is itself a role claim.
internal struct PairingHello: Equatable {
  internal var parameters: NegotiatedParameters

  internal var displayName: String

  internal var platform: String

  internal var requestedProfiles: [ProfileName]?

  internal static func from(body: [String: WireValue]) throws -> Self {
    var fields = body
    let decodedParameters = try NegotiatedParameters.from(
      map: takeMessageMap(&fields, "parameters"))
    let decodedDisplayName = try takeMessageText(&fields, "display_name")
    let decodedPlatform = try takeMessageText(&fields, "platform")
    var requested: [ProfileName]?
    if let value = fields.removeValue(forKey: "requested_profiles") {
      guard case .array(let names) = value else {
        throw MessageFieldError.invalidField("requested_profiles")
      }
      requested = try names.map(profileName)
    }
    guard fields.isEmpty else { throw MessageFieldError.invalidField("body") }
    try validateLabel(decodedDisplayName, "display_name")
    try validateLabel(decodedPlatform, "platform")
    return Self(
      parameters: decodedParameters, displayName: decodedDisplayName,
      platform: decodedPlatform,
      requestedProfiles: requested)
  }

  internal func body() throws -> [String: WireValue] {
    try validateLabel(displayName, "display_name")
    try validateLabel(platform, "platform")
    if let requestedProfiles { try validateProfileSet(requestedProfiles) }
    var fields: [String: WireValue] = [
      "parameters": .map(try parameters.asMap()),
      "display_name": .text(displayName),
      "platform": .text(platform),
    ]
    if let requestedProfiles {
      fields["requested_profiles"] = .array(requestedProfiles.map { .text($0.rawValue) })
    }
    return fields
  }
}
