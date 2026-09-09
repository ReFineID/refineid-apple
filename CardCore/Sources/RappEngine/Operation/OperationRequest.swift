// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One typed request, bound to a pairing and a session.
///
/// The request hash covers every field a holder is shown and every field the
/// card acts on, so an approval cannot be moved to a different request.
internal struct OperationRequest: Equatable {
  internal let operationIdentifier: Data

  internal let pairIdentifier: Data

  internal let sessionIdentifier: Data

  internal let profile: ProfileName

  /// Local monotonic receipt time.
  ///
  /// Never sent and never hashed.
  internal let localStartMilliseconds: UInt64

  /// Relative validity the peer sends, capped again by local policy.
  internal let expiresAfterMilliseconds: UInt64

  internal let operation: CardOperation

  internal init(
    operationIdentifier: Data,
    pairIdentifier: Data,
    sessionIdentifier: Data,
    profile: ProfileName,
    localStartMilliseconds: UInt64,
    expiresAfterMilliseconds: UInt64,
    operation: CardOperation
  ) throws {
    self.operationIdentifier = operationIdentifier
    self.pairIdentifier = pairIdentifier
    self.sessionIdentifier = sessionIdentifier
    self.profile = profile
    self.localStartMilliseconds = localStartMilliseconds
    self.expiresAfterMilliseconds = expiresAfterMilliseconds
    self.operation = operation
    try validate()
  }

  /// Parses a received request and recomputes its hash rather than trusting
  /// the one on the wire.
  internal static func from(
    wireBody: [String: WireValue],
    pairIdentifier: Data,
    sessionIdentifier: Data,
    localStartMilliseconds: UInt64
  ) throws -> Self {
    var body = wireBody
    let decodedOperationIdentifier = try takeOperationBytes(&body, "operation_id")
    guard let decodedProfile = ProfileName(rawValue: try takeOperationText(&body, "profile"))
    else {
      throw CardOperationError.unknownProfile
    }
    let action = try takeOperationText(&body, "action")
    let claimedHash = try takeOperationBytes(&body, "request_hash")
    let decodedExpiresAfterMilliseconds = try takeOperationUnsigned(&body, "expires_after_ms")
    let context = try takeOperationMap(&body, "context")
    let payload = try takeOperationMap(&body, "payload")
    guard body.isEmpty else { throw CardOperationError.unexpectedField }
    guard claimedHash.count == OperationSize.requestHash else {
      throw CardOperationError.invalidIdentifier
    }
    let decodedOperation = try CardOperation.from(
      action: action, context: context, payload: payload)
    let request = try Self(
      operationIdentifier: decodedOperationIdentifier,
      pairIdentifier: pairIdentifier,
      sessionIdentifier: sessionIdentifier,
      profile: decodedProfile,
      localStartMilliseconds: localStartMilliseconds,
      expiresAfterMilliseconds: decodedExpiresAfterMilliseconds,
      operation: decodedOperation)
    guard try request.requestHash() == claimedHash else {
      throw CardOperationError.requestHashMismatch
    }
    return request
  }

  /// Rejects a request whose identifiers, lifetime, or profile do not agree.
  internal func validate() throws {
    guard operationIdentifier.count == OperationSize.operationIdentifier,
      pairIdentifier.count == OperationSize.pairIdentifier,
      sessionIdentifier.count == OperationSize.sessionIdentifier
    else { throw CardOperationError.invalidIdentifier }
    guard expiresAfterMilliseconds > 0 else { throw CardOperationError.invalidLifetime }
    guard profile == operation.requiredProfile else {
      throw CardOperationError.profileActionMismatch
    }
    try operation.validate()
  }

  /// The pairing must have granted the profile this action belongs to.
  ///
  /// This is
  /// checked before any card contact.
  internal func requireGranted(by granted: [ProfileName]) throws {
    guard granted.contains(profile) else { throw CardOperationError.profileNotGranted }
  }

  /// Local monotonic deadline, shortened by this endpoint's own maximum.
  internal func localDeadlineMilliseconds(maximumLifetimeMilliseconds: UInt64) throws -> UInt64 {
    try validate()
    guard maximumLifetimeMilliseconds > 0 else { throw CardOperationError.invalidLifetime }
    let lifetime = min(expiresAfterMilliseconds, maximumLifetimeMilliseconds)
    let (deadline, overflowed) = localStartMilliseconds.addingReportingOverflow(lifetime)
    return overflowed ? UInt64.max : deadline
  }

  /// What the approval and the durable journal commit to.
  internal func requestHash() throws -> Data {
    try validate()
    let binding = RappRequestBinding(
      sessionIdentifier: sessionIdentifier,
      operationIdentifier: operationIdentifier,
      profile: profile.rawValue,
      action: operation.action,
      context: operation.context,
      payload: operation.payload)
    do {
      return try RappHashes.requestHash(of: binding)
    } catch {
      throw CardOperationError.hashFailure
    }
  }

  /// The exact `operation.request` body.
  internal func wireBody() throws -> [String: WireValue] {
    [
      "operation_id": .bytes(operationIdentifier),
      "profile": .text(profile.rawValue),
      "action": .text(operation.action),
      "request_hash": .bytes(try requestHash()),
      "expires_after_ms": .unsigned(expiresAfterMilliseconds),
      "context": .map(operation.context),
      "payload": .map(operation.payload),
    ]
  }
}
