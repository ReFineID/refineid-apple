// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// An authenticated session that is not healthy until both parameter echoes
/// have been sent and verified.
internal struct SessionAuthentication {
  private let role: EndpointRole
  private let pairIdentifier: Data
  internal let sessionIdentifier: Data
  private let expectedParameters: SessionParameters
  private var channel: RappMessageChannel?

  private var localReadySent = false
  private var peerReadyReceived = false

  internal init(
    role: EndpointRole,
    pairIdentifier: Data,
    sessionIdentifier: Data,
    expectedParameters: SessionParameters,
    channel: RappMessageChannel
  ) {
    self.role = role
    self.pairIdentifier = pairIdentifier
    self.sessionIdentifier = sessionIdentifier
    self.expectedParameters = expectedParameters
    self.channel = channel
  }

  /// Send this side's exact parameters with a fresh nonce.
  internal mutating func sendReady(nonce: Data) throws -> Data {
    guard !localReadySent else { throw SessionError.duplicateReady }
    let ready = SessionReady(parameters: expectedParameters, nonce: nonce)
    let body: [String: WireValue]
    do {
      body = try ready.body()
    } catch let error as MessageFieldError {
      throw SessionError.message(error)
    }
    guard var working = channel else { throw SessionError.closed }
    let frame: Data
    do {
      frame = try working.seal(.sessionReady, body: body)
    } catch {
      throw SessionError.noise
    }
    channel = working
    localReadySent = true
    return frame
  }

  /// Verify the peer's echo.
  ///
  /// A decrypted mismatch is an authenticated
  /// violation and ends the pairing; a decryption failure ends the session only.
  internal mutating func receiveReady(_ frame: Data) throws {
    if peerReadyReceived { throw endPairing(.duplicateReady) }
    guard var working = channel else { throw SessionError.closed }

    let envelope: Envelope
    do {
      envelope = try working.open(frame)
    } catch RappOpenFailure.sessionIntegrityFailure {
      channel = nil
      throw SessionError.integrityFailure
    } catch {
      throw endPairing(.wireViolation)
    }
    channel = working

    guard envelope.messageType == .sessionReady else { throw endPairing(.unexpectedMessage) }
    let ready: SessionReady
    do {
      ready = try SessionReady.from(body: envelope.body)
    } catch {
      throw endPairing(.malformedMessage)
    }
    guard ready.parameters == expectedParameters else { throw endPairing(.parameterMismatch) }
    peerReadyReceived = true
  }

  /// Promote to a healthy session only once both echoes verified.
  internal consuming func intoEstablished() throws -> EstablishedSession {
    guard localReadySent, peerReadyReceived else { throw SessionError.readyIncomplete }
    guard let channel else { throw SessionError.closed }
    return EstablishedSession(
      role: role, pairIdentifier: pairIdentifier, sessionIdentifier: sessionIdentifier,
      channel: channel)
  }

  private mutating func endPairing(_ violation: SessionViolation) -> SessionError {
    channel = nil
    return SessionError.pairingMustEnd(cause: violation)
  }
}
