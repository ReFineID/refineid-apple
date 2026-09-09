// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Network

/// Holds the endpoints a browser reported.
internal actor StreamRelayEndpointBox {
  private var endpoints: [NWEndpoint] = []

  /// Records one found endpoint.
  internal func set(_ endpoint: NWEndpoint) {
    endpoints.append(endpoint)
  }

  /// The endpoint published under `name`, if one was found.
  ///
  /// A network carries other people's services, so a test takes the one it
  /// published rather than the first that answered.
  internal func matching(_ name: String) -> NWEndpoint? {
    endpoints.first { endpoint in
      guard case .service(let serviceName, _, _, _) = endpoint else { return false }
      return serviceName == name
    }
  }
}
