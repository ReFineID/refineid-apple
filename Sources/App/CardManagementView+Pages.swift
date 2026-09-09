// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

extension CardManagementView {
  // MARK: Static Functions

  private static func spentAttempts(
    _ report: CredentialProbeReport
  ) -> [(name: String, remaining: RetryCount)] {
    [("PIN 1", report.pin1), ("PIN 2", report.pin2), ("PUK", report.puk)]
      .compactMap { name, outcome in
        guard case .remaining(let count) = outcome, !count.isPristine
        else { return nil }
        return (name, count)
      }
  }

  internal static func initialTask(
    for recovery: CredentialRetryHealth.Recovery?
  ) -> ManagementTask {
    switch recovery {
    case .resetPin1:
      .resetPin1

    case .resetPin2:
      .resetPin2

    case .useOtherSoftware, .unrecoverable, nil:
      .changePin1
    }
  }

  // MARK: Content Views

  @ViewBuilder
  internal func recoveryGuidanceSection(
    retryHealth: CredentialRetryHealth,
    model: CardManagementModel
  ) -> some View {
    if model.failure == nil, model.notice == nil {
      switch retryHealth.recovery {
      case .resetPin1:
        Section {
          CredentialOutcomeText(
            message: CredentialOutcomeMessage.recoveryGuidance(for: .pin1),
            tone: .notice)
        }

      case .resetPin2:
        Section {
          CredentialOutcomeText(
            message: CredentialOutcomeMessage.recoveryGuidance(for: .pin2),
            tone: .notice)
        }

      case .useOtherSoftware:
        Section {
          CredentialOutcomeText(
            message: CredentialOutcomeMessage.otherSoftwareRecovery(),
            tone: .failure)
        }

      case .unrecoverable:
        Section {
          CredentialOutcomeText(
            message: CredentialOutcomeMessage.unrecoverableCard(),
            tone: .failure)
        }

      case nil:
        spentAttemptsSection(retryHealth: retryHealth)
      }
    }
  }

  /// The yellow key's explanation: which codes have spent attempts,
  /// how many remain, and that one correct entry restores them all.
  @ViewBuilder
  internal func spentAttemptsSection(
    retryHealth: CredentialRetryHealth
  ) -> some View {
    if retryHealth.level == .warning, let report = retryHealth.report {
      let spent = Self.spentAttempts(report)
      if !spent.isEmpty {
        Section {
          CredentialOutcomeText(
            message: CredentialOutcomeMessage.spentAttemptsNotice(spent),
            tone: .notice)
        }
      }
    }
  }

  @ViewBuilder
  internal func connectionSection(
    model: CardManagementModel,
    readerCardIsPresent: Bool,
    usesProvidedCardAccessNumber: Bool
  ) -> some View {
    #if os(iOS)
      if !readerCardIsPresent,
        model.transport == .nearField,
        !usesProvidedCardAccessNumber
      {
        Section("NFC") {
          TextField(
            "Card Access Number (CAN)",
            text: Binding(
              get: { model.cardAccessNumber },
              set: { model.cardAccessNumber = $0 }
            )
          )
          .textContentType(.oneTimeCode)
          .keyboardType(.numberPad)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .onValueChange(of: model.cardAccessNumber) { typed in
            model.cardAccessNumber = LimitedDigits.cardAccessNumber(typed)
          }
          .accessibilityIdentifier("managementCardAccessNumber")
          Button("Read card") {
            Task { await model.refresh() }
          }
          .disabled(model.cardOperationInProgress || !model.canContactCard)
          .accessibilityIdentifier("managementReadCard")
        }
      }
    #endif
  }

  /// The form one tab shows.
  @ViewBuilder
  internal func page(
    for task: ManagementTask,
    model: CardManagementModel
  ) -> some View {
    switch task {
    case .changePin1:
      CredentialChangeSection(model: model, credential: .pin1)

    case .changePin2:
      CredentialChangeSection(model: model, credential: .pin2)

    case .resetPin1:
      CredentialUnblockSection(model: model, target: .pin1)

    case .resetPin2:
      CredentialUnblockSection(model: model, target: .pin2)
    }
  }
}
