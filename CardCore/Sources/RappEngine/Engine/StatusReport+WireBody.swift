// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension StatusReport {
  /// The exact `operation.status` wire body.
  ///
  /// An unknown operation omits `state` and `request_hash` entirely, giving a
  /// two-key map. This is deliberately NOT the journal's encoding, which
  /// writes both as explicit null to keep its map arity constant. The two
  /// serve different readers and no peer accepts the journal's shape, so they
  /// stay separate functions.
  internal var wireBody: [String: WireValue] {
    var body: [String: WireValue] = [
      "operation_id": .bytes(operationIdentifier),
      "known": .boolean(known),
    ]
    if let state {
      body["state"] = .text(state.rawValue)
    }
    if let requestHash {
      body["request_hash"] = .bytes(requestHash)
    }
    return body
  }
}
