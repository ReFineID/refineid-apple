// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The encrypted channel that carries every message after the handshake.
///
/// Each direction owns a cipher state whose counter starts at zero, so the two
/// directions never share a nonce.
internal struct RappSecureChannel {
  private var send: NoiseCipherState
  private var receive: NoiseCipherState

  internal init(send: NoiseCipherState, receive: NoiseCipherState) {
    self.send = send
    self.receive = receive
  }

  /// Encrypt one plaintext and advance the send counter once.
  internal mutating func seal(_ plaintext: Data) throws -> Data {
    guard plaintext.count <= RappFrameLimits.maximumPlaintext else {
      throw RappFrameError.oversized(
        got: plaintext.count + NoiseSizes.tagLength, maximum: RappFrameLimits.maximumFrame)
    }
    return try send.encrypt(associatedData: Data(), plaintext: plaintext)
  }

  /// Decrypt one frame, then hand the plaintext to the caller's validator.
  ///
  /// A decryption failure is unattributable; a validator rejection is an
  /// authenticated protocol violation.
  /// Decrypt one frame with no further validation.
  internal mutating func open(_ frame: Data) throws -> Data {
    try open(frame) { _ in
      // Nothing beyond decryption is asserted about this frame.
    }
  }

  internal mutating func open(
    _ frame: Data,
    validate: (Data) throws -> Void
  ) throws -> Data {
    guard frame.count <= RappFrameLimits.maximumFrame else {
      throw RappFrameError.oversized(got: frame.count, maximum: RappFrameLimits.maximumFrame)
    }
    let plaintext: Data
    do {
      plaintext = try receive.decrypt(associatedData: Data(), ciphertext: frame)
    } catch {
      throw RappOpenFailure.sessionIntegrityFailure
    }
    do {
      try validate(plaintext)
    } catch {
      throw RappOpenFailure.authenticatedProtocolViolation
    }
    return plaintext
  }
}
