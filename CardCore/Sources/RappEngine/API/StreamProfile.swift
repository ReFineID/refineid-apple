// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

// A candidate that advertises no endpoints is not the same as one that is not
// a stream candidate at all, so the answer is optional.
// swiftlint:disable discouraged_optional_collection

/// The `fi.refineid.stream.v1` transport profile.
///
/// The engine owns the profile's name and the shape of its parameters, so a
/// caller never assembles either.
internal enum StreamProfile {
  internal static let name = "fi.refineid.stream.v1"

  /// The parameter key carrying a candidate's listener endpoints.
  internal static let endpointsKey = "endpoints"

  /// Upper bound on endpoints one candidate may advertise.
  internal static let maximumEndpoints = 8

  /// Upper bound on one endpoint's length, in bytes.
  internal static let maximumEndpointBytes = 255

  /// The endpoints a candidate advertises, or nothing when it is not a
  /// stream candidate or carries none.
  internal static func endpoints(of candidate: TransportCandidate) -> [String]? {
    guard candidate.profile == name,
      case .array(let values)? = candidate.parameters[endpointsKey]
    else { return nil }
    var endpoints: [String] = []
    for value in values {
      guard case .text(let endpoint) = value else { return nil }
      endpoints.append(endpoint)
    }
    return endpoints.isEmpty ? nil : endpoints
  }
}

// swiftlint:enable discouraged_optional_collection
