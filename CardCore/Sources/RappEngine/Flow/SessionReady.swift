// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The proof each side sends before a session may carry operations.
internal struct SessionReady: Equatable {
  internal var parameters: SessionParameters

  internal var nonce: Data

  internal static func from(body: [String: WireValue]) throws -> Self {
    var fields = body
    let decodedParameters = try SessionParameters.from(map: takeMessageMap(&fields, "parameters"))
    let decodedNonce = try takeMessageBytes(&fields, "nonce")
    guard fields.isEmpty, decodedNonce.count == FlowLimit.readyNonce else {
      throw MessageFieldError.invalidField("nonce")
    }
    return Self(parameters: decodedParameters, nonce: decodedNonce)
  }

  internal func body() throws -> [String: WireValue] {
    guard nonce.count == FlowLimit.readyNonce else {
      throw MessageFieldError.invalidField("nonce")
    }
    return ["parameters": .map(try parameters.asMap()), "nonce": .bytes(nonce)]
  }
}
