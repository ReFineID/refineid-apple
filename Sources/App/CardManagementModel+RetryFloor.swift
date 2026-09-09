// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore

extension CardManagementModel {
  /// Mirrors the card-side floor in the form without replacing it.
  ///
  /// A missing report keeps the form responsive while the asynchronous probe
  /// arrives. Once a credential-specific reading exists, the UI cannot offer
  /// an operation the fresh same-session backend probe would refuse.
  /// Activation may write either PIN independently.
  ///
  /// Every PIN still awaiting its factory-state write must be above the
  /// same retry floor.
  internal var allowsActivationOperation: Bool {
    (!activationNeeds.pin1 || allowsCredentialOperation(spending: .pin1))
      && (!activationNeeds.pin2 || allowsCredentialOperation(spending: .pin2))
  }

  private func retryOutcome(for role: CredentialRole) -> RetryProbeOutcome? {
    switch role {
    case .pin1:
      report?.pin1

    case .pin2:
      report?.pin2

    case .puk:
      report?.puk
    }
  }

  internal func allowsCredentialOperation(spending role: CredentialRole) -> Bool {
    guard let outcome = retryOutcome(for: role) else { return true }
    return RetryFloor.evaluate(probeOutcome: outcome) == .proceed
  }
}
