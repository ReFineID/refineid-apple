// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A peer cancellation.
///
/// The reason is a bounded free-text label, not a registered error name: the
/// protocol lets a peer say why in its own words, and a closed enumeration
/// here could neither send nor accept what a conforming peer writes.
internal struct CancelMessage: Equatable {
  internal let reference: OperationReference

  internal let reason: String?

  internal static func from(wireBody: [String: WireValue]) throws -> Self {
    var body = wireBody
    var decodedReason: String?
    if let value = body.removeValue(forKey: "reason") {
      guard case .text(let text) = value, EngineLabel.isValid(text) else {
        throw CardOperationError.invalidField(field: "reason")
      }
      decodedReason = text
    }
    return Self(
      reference: try OperationReference.from(wireBody: body), reason: decodedReason)
  }

  /// The exact `operation.cancel` body, omitting an absent reason.
  internal func wireBody() throws -> [String: WireValue] {
    var body = reference.wireBody
    guard let reason else { return body }
    guard EngineLabel.isValid(reason) else {
      throw CardOperationError.invalidField(field: "reason")
    }
    body["reason"] = .text(reason)
    return body
  }
}
