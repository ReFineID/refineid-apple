// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Translations between the public vocabulary and the engine's own.
///
/// The public names are the ones callers already wrote against, so they are
/// kept even where the engine spells a value differently.
extension RappEndpointRole {
  internal var engineRole: EndpointRole {
    switch self {
    case .requester:
      .requester

    case .proxy:
      .proxy
    }
  }

  internal init(_ role: EndpointRole) {
    switch role {
    case .requester:
      self = .requester

    case .proxy:
      self = .proxy
    }
  }
}
