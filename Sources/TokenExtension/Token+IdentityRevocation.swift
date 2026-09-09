// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore

/// Revokes persistent automatic-signing authority on a confirmed credential refusal.
extension Token {
  /// Revokes automatic signing authority after this card rejects PIN1.
  ///
  /// This path is deliberately narrower than a generic sign failure.
  /// Transport loss, PACE failure, malformed signatures, and TLS errors do
  /// not touch stored state. Only the card's VERIFY response reaches here.
  ///
  /// The rejected fingerprint is process state. Accepted PIN1 is this
  /// token's and leaves with it. The stored PIN and prime are persistent
  /// authority, so they are removed before the failure returns.
  /// Registration removal is queued off the CTK callback thread to avoid
  /// asking ctkd to unregister a token while ctkd is still executing that
  /// token's sign callback.
  internal func revokeAutomaticIdentityAfterPin1Rejection(
    serial: TokenSerial,
    fingerprint: PinFingerprint
  ) {
    revokeCurrentInstance()
    CredentialMemory.rejectedPins.recordRejection(fingerprint)
    acceptedPin1.clear(serial: serial)

    guard CardInstanceIdentifier(tokenSerial: serial) == cardInstanceID else {
      TokenLog.error("PIN1 rejection serial did not match token instance")
      return
    }

    revokeStoredAutomaticIdentity(
      reason: .pin1Rejection,
      forgetCardAccessNumber: false,
      forgetPin1: true
    )
  }

  /// Revokes the complete automatic identity after PACE proves that the
  /// stored CAN and the presented card cannot authenticate each other.
  internal func revokeAutomaticIdentityAfterCanRejection() {
    revokeCurrentInstance()
    if let serial = primedSerial {
      acceptedPin1.clear(serial: serial)
    }
    revokeStoredAutomaticIdentity(
      reason: .canRejection,
      forgetCardAccessNumber: true,
      forgetPin1: true
    )
  }

  /// Revokes the live and stored token after this card rejects PIN2.
  ///
  /// PIN2 is never persisted, and a PIN2 rejection does not invalidate
  /// the independently proven CAN or PIN1 credentials.
  internal func revokeIdentityAfterPin2Rejection(
    serial: TokenSerial,
    fingerprint: PinFingerprint
  ) {
    revokeCurrentInstance()
    CredentialMemory.rejectedPins.recordRejection(fingerprint)
    acceptedPin1.clear(serial: serial)

    guard CardInstanceIdentifier(tokenSerial: serial) == cardInstanceID else {
      TokenLog.error("PIN2 rejection serial did not match token instance")
      return
    }

    revokeStoredAutomaticIdentity(
      reason: .pin2Rejection,
      forgetCardAccessNumber: false,
      forgetPin1: false
    )
  }

  /// Removes every persistent and live capability of this automatic token.
  ///
  /// A bad CAN also removes PIN1 because neither secret may remain attached
  /// to an identity whose physical card could not be authenticated.
  private func revokeStoredAutomaticIdentity(
    reason: TokenRegistrationRevoker.Reason,
    forgetCardAccessNumber: Bool,
    forgetPin1: Bool
  ) {
    let representsStoredIdentity: Bool =
      switch interface {
      case .fieldWithDeadline:
        true

      case .contact, .steadyField:
        PrimeStore.contains(instanceID: cardInstanceID)
      }
    guard representsStoredIdentity else {
      TokenLog.notice("\(reason.logPrefix); no stored automatic identity belonged to this token")
      return
    }

    if forgetCardAccessNumber {
      CardCredentialStore.forgetAll()
    } else if forgetPin1 {
      CardCredentialStore.forgetPin1()
    }
    PrimeStore.forget(instanceID: cardInstanceID)
    PrimeStore.forgetStaged()
    TokenRegistrationRevoker.revoke(cardInstanceID, reason: reason)
    TokenLog.error("\(reason.logPrefix); automatic identity revoked")
  }
}
