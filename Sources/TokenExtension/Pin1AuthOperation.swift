// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoTokenKit
import Foundation

/// The PIN1 prompt for a signing operation.
///
/// CryptoTokenKit presents the system secure-entry UI and sets
/// `password`; `finish()` captures it for the matching `sign`, which
/// verifies PIN1 and runs the signature in one card session. Capturing
/// here rather than verifying here keeps VERIFY and the signature in a
/// single transport scope, so the card's PIN state cannot lapse between
/// them.
internal final class Pin1AuthOperation: TKTokenPasswordAuthOperation {
  /// The constraint marker the published signing key carries for signing.
  ///
  /// CryptoTokenKit stores it against the key and hands it back in
  /// `beginAuthFor`, which is how the system knows a signature is gated
  /// behind a PIN1 prompt - without a constraint the system signs without
  /// ever asking, so Safari selects the identity but no PIN appears and
  /// the handshake fails.
  internal static let signDataConstraint = "fi.refineid.pin1.signData"

  private let capture: (String) -> Void

  internal init(capture: @escaping (String) -> Void) {
    self.capture = capture
    super.init()
  }

  // CryptoTokenKit never archives a live auth operation, so decoding one
  // is unreachable; the initializer exists only for NSSecureCoding.
  internal required init?(coder: NSCoder) {
    self.capture = { _ in
      // Unreachable: a decoded operation is never finished.
    }
    super.init(coder: coder)
  }

  override internal func finish() throws {
    guard let pin = password, !pin.isEmpty else {
      throw TKError(.authenticationFailed)
    }
    capture(pin)
  }
}
