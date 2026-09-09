// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import os

/// The stateful SCS transaction flow (DVV SCS specification v1.3
/// §2.7): a signed `begin` establishes an encrypted channel, one
/// `execute` inside it produces the signature.
///
/// `begin` arrives as a compact JWS signed by the relying service's
/// certificate; its payload carries the service's P-256 agreement
/// key. This service answers with an ephemeral public key, signed by
/// the card, and both sides derive the shared transaction key.
/// `execute` then rides as a direct-encryption A256GCM JWE under that
/// key, and so does its response. One transaction may be pending at a
/// time; `execute` consumes it whether it succeeds or not. The step
/// logic lives in `ScsTransactionBegin` and
/// `ScsTransactionExecution`; this class owns only the pending slot.
public final class ScsTransactionManager: Sendable {
  private let pending = OSAllocatedUnfairLock<ScsAgreedTransaction?>(initialState: nil)

  /// Creates a manager with no pending transaction.
  public init() {
    // Starts empty by definition: no transaction has begun.
  }

  /// Handles the `begin` JWS: verifies it, agrees the transaction
  /// key, and answers the card-signed response JWT.
  public func begin(
    compactJws: Data,
    origin: String?,
    at now: Date,
    backend: any ScsSigningBackend
  ) -> Result<String, ScsTransactionError> {
    let requestOrigin: String
    switch ScsTransactionCodec.validatedOrigin(origin) {
    case .success(let validated):
      requestOrigin = validated

    case .failure(let error):
      return .failure(error)
    }
    guard let compact = String(data: compactJws, encoding: .utf8) else {
      return .failure(.badRequest("JWT body is not UTF-8"))
    }
    let segments = compact.components(separatedBy: ".")
    guard
      segments.count == ScsValues.jwsSegmentCount,
      segments.allSatisfy({ segment in !segment.isEmpty })
    else {
      return .failure(.badRequest("begin transaction must be a compact JWS"))
    }
    if pending.withLock({ current in current != nil }) {
      return .failure(.forbidden("another signature request is already active"))
    }
    let outcome: ScsTransactionBegin.Outcome
    switch ScsTransactionBegin.perform(
      segments: segments, origin: requestOrigin, at: now, backend: backend)
    {
    case .success(let performed):
      outcome = performed

    case .failure(let error):
      return .failure(error)
    }
    let raced = pending.withLock { current in
      if current != nil {
        return true
      }
      current = outcome.state
      return false
    }
    guard !raced else {
      return .failure(.forbidden("another signature request became active"))
    }
    return .success(outcome.response)
  }

  /// Handles the `execute` JWE.
  ///
  /// Decrypts it under the pending key, signs, and answers the
  /// encrypted response; the pending transaction is consumed either
  /// way.
  public func execute(
    compactJwe: Data,
    origin: String?,
    backend: any ScsSigningBackend
  ) -> Result<String, ScsTransactionError> {
    let requestOrigin: String
    switch ScsTransactionCodec.validatedOrigin(origin) {
    case .success(let validated):
      requestOrigin = validated

    case .failure(let error):
      return .failure(error)
    }
    guard
      let state = pending.withLock({ current in
        let taken = current
        current = nil
        return taken
      })
    else {
      return .failure(.badRequest("no active transaction"))
    }
    guard state.origin == requestOrigin else {
      return .failure(.forbidden("execute Origin does not match begin Origin"))
    }
    let payloadBytes: Data
    switch ScsJsonWebEncryption.decrypt(compact: compactJwe, key: state.key) {
    case .success(let decrypted):
      payloadBytes = decrypted

    case .failure(let error):
      return .failure(error)
    }
    guard
      let payload = try? JSONDecoder().decode(ScsExecuteDocument.self, from: payloadBytes)
    else {
      return .failure(.badRequest("execute payload is not valid JSON"))
    }
    return ScsTransactionExecution.respond(
      payload: payload, state: state, backend: backend)
  }
}
