// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

/// User-facing presentation shared by every credential operation.
///
/// Card operations own retry policy and return structured outcomes. This type
/// owns the corresponding wording and typography so management, activation,
/// authentication, and signing do not invent separate rejection messages.
internal enum CredentialOutcomeMessage {
  internal static func rejection(
    credentialName: String,
    remaining: RetryCount
  ) -> String {
    incorrect(credentialName: credentialName)
      + "\n"
      + String(
        localized: "You have \(remaining.attemptsRemaining) attempts remaining.")
  }

  internal static func lowAttemptRefusal() -> String {
    String(localized: "The operation was not sent.")
      + "\n"
      + String(
        localized: "RefineID does not use either of the last two attempts.")
  }

  /// A retry-floor refusal when the card supplied the exact counter.
  ///
  /// Keeping the count here lets every credential flow use the same wording
  /// and the same two-line visual hierarchy instead of calling it a vague
  /// safety failure.
  internal static func lowAttemptRefusal(
    credentialName: String,
    remaining: RetryCount
  ) -> String {
    let detail =
      if remaining.attemptsRemaining == 1 {
        String(localized: "Only 1 attempt remains for \(credentialName).")
      } else {
        String(
          localized:
            "Only \(remaining.attemptsRemaining) attempts remain for \(credentialName).")
      }
    return String(localized: "Operation refused")
      + "\n"
      + detail
      + "\n"
      + String(
        localized: "Use another software or reset \(credentialName).")
  }

  /// Which credentials have spent attempts, and the way back to the
  /// full allowance: one correct entry.
  internal static func spentAttemptsNotice(
    _ spent: [(name: String, remaining: RetryCount)]
  ) -> String {
    let full = Int(RetryCount.pristineAllowance)
    let lines = spent.map { entry in
      String(
        localized:
          "\(entry.name): \(Int(entry.remaining.attemptsRemaining)) of \(full) attempts left."
      )
    }
    return lines.joined(separator: "\n")
      + "\n"
      + String(localized: "A correct entry restores the full count.")
  }

  internal static func recoveryGuidance(for role: CredentialRole) -> String {
    switch role {
    case .pin1:
      String(localized: "PIN 1 requires recovery")
        + "\n"
        + String(localized: "Reset PIN 1 with your PUK.")

    case .pin2:
      String(localized: "PIN 2 requires recovery")
        + "\n"
        + String(localized: "Reset PIN 2 with your PUK.")

    case .puk:
      preconditionFailure("PUK is the recovery credential, not a reset target")
    }
  }

  internal static func otherSoftwareRecovery() -> String {
    String(localized: "Use other software to recover the card")
      + "\n"
      + String(
        localized: "RefineID will not use either of the final two PUK attempts.")
  }

  internal static func unrecoverableCard() -> String {
    String(localized: "The PUK is blocked")
      + "\n"
      + String(localized: "This card cannot be recovered with software.")
  }

  internal static func incorrect(credentialName: String) -> String {
    switch credentialName {
    case "PIN 1":
      String(localized: "PIN 1 is incorrect.")

    case "PIN 2":
      String(localized: "PIN 2 is incorrect.")

    case "PUK":
      String(localized: "PUK is incorrect.")

    case "activation code":
      String(localized: "Activation code is incorrect.")

    case "activation PIN":
      String(localized: "Activation PIN is incorrect.")

    default:
      "\(credentialName) is incorrect."
    }
  }
}
