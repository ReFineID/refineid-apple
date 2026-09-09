// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import Foundation
  import SwiftUI
  import UIKit

  /// Process-scoped demonstration and UI-test environment.
  ///
  /// The environment owns an explicit VirtualIDCard. It never falls through to
  /// physical card I/O, Keychain storage, token registration, or production
  /// diagnostics. Quitting the process destroys both its card and device state.
  @MainActor
  internal final class DemoMode: ObservableObject {
    // MARK: Static Properties

    internal static let shared = DemoMode()

    internal static let launchArgument = "--virtual-card"

    /// A demonstration fakes the antenna, never the device class: only
    /// an iPhone is offered near-field states.
    internal static let offersNearField =
      UIDevice.current.userInterfaceIdiom == .phone

    // MARK: Static Computed Properties

    /// The scenario a demonstration starts from on this device class.
    ///
    /// A demonstration walks only the flows the build offers. With
    /// activation shipping, the card arrives factory fresh so the whole
    /// journey can be shown; with activation gated, it arrives already
    /// activated - exactly like the card of a holder who activated it
    /// elsewhere - so the demonstration starts where the product does.
    internal static var defaultScenario: VirtualIDCard.Scenario {
      #if FEATURE_CARD_ACTIVATION
        offersNearField ? .factoryFreshNearField : .factoryFreshReader
      #else
        offersNearField ? .activatedNearField : .activatedReader
      #endif
    }

    // MARK: Properties

    @Published internal private(set) var isActive = false
    @Published internal private(set) var state = DemoMode.defaultScenario.snapshot
    @Published internal private(set) var revision = 0
    @Published internal private(set) var isEditorPresented = false

    private var card = VirtualIDCard(scenario: DemoMode.defaultScenario)

    // MARK: Computed Properties

    internal var isHolding: Bool { false }

    internal var hasIdentity: Bool {
      state.device.cachedIdentity && state.device.tokenRegistered
    }

    internal var holderName: String {
      state.card.holderName + " " + state.card.electronicClientIdentifier
    }

    internal var hasValidatedConnection: Bool {
      state.device.connectedCardAccessNumber != nil
        || state.device.storedCardAccessNumber != nil
    }

    internal var displayedCardAccessNumber: String? {
      state.device.storedCardAccessNumber
        ?? state.device.connectedCardAccessNumber
    }

    internal var isReaderCardPresent: Bool {
      state.card.transport == .reader
        && state.card.readerConnected
        && state.card.cardPresent
    }

    internal var activationNeeds: CardActivationNeeds {
      CardActivationNeeds(
        pin1: state.card.pin1.isFactoryValue,
        pin2: state.card.pin2.isFactoryValue)
    }

    internal var activationScheme: ActivationScheme {
      Self.scheme(for: state.card.generation)
    }

    // MARK: Static Functions

    private static func scheme(
      for generation: VirtualIDCard.Generation
    ) -> ActivationScheme {
      switch generation {
      case .activationCodeIsPuk:
        .activationCodeIsPuk

      case .presetActivationPIN:
        .presetActivationPin
      }
    }

    private static func maintenanceSnapshot(
      from snapshot: VirtualIDCard.Snapshot,
      retryReport: VirtualIDCard.RetryReport? = nil,
      report suppliedReport: CredentialProbeReport? = nil
    ) -> CardMaintenance.Snapshot {
      let report =
        suppliedReport
        ?? retryReport.map(Self.report(from:))
        ?? Self.report(from: snapshot.card)
      return CardMaintenance.Snapshot(
        report: report,
        activationNeeds: CardActivationNeeds(
          pin1: snapshot.card.pin1.isFactoryValue,
          pin2: snapshot.card.pin2.isFactoryValue),
        activationScheme: Self.scheme(for: snapshot.card.generation))
    }

    private static func report(
      from card: VirtualIDCard.CardState
    ) -> CredentialProbeReport {
      CredentialProbeReport(
        pin1: retryOutcome(card.pin1.attemptsRemaining),
        pin2: retryOutcome(card.pin2.attemptsRemaining),
        puk: retryOutcome(card.puk.attemptsRemaining))
    }

    private static func report(
      from report: VirtualIDCard.RetryReport
    ) -> CredentialProbeReport {
      CredentialProbeReport(
        pin1: retryOutcome(report.pin1),
        pin2: retryOutcome(report.pin2),
        puk: retryOutcome(report.puk))
    }

    private static func retryOutcome(_ attempts: UInt8) -> RetryProbeOutcome {
      guard let count = RetryCount(attemptsRemaining: attempts) else {
        return .noInformation
      }
      return count.isBlocked ? .locked : .remaining(count)
    }

    private static func outcome(
      from outcome: VirtualIDCard.CredentialOutcome
    ) -> CardMaintenance.Outcome {
      switch outcome {
      case .success:
        .success

      case .alreadyActivated:
        .alreadyActivated

      case .invalidEntry:
        .invalidEntry

      case .blocked:
        .pinBlocked

      case .rejected(let remaining):
        RetryCount(attemptsRemaining: remaining)
          .map { .rejected(remaining: $0) }
          ?? .failed

      case .refusedLowAttempts:
        .floorRefused(.refuseLowAttempts)

      case .transportFailure(let effect):
        switch effect {
        case .connectionLost, .readerDisconnected, .cardRemoved:
          .noCard

        case .timeout, .malformedResponse, .tokenNotPublished:
          .failed
        }
      }
    }

    // MARK: Functions

    internal func setEditorPresented(_ presented: Bool) {
      isEditorPresented = presented
    }

    internal func activate(
      scenario: VirtualIDCard.Scenario = DemoMode.defaultScenario
    ) {
      isActive = true
      state = scenario.snapshot
      card = VirtualIDCard(snapshot: state)
      publishState()
    }

    #if DEBUG
      internal func activateFromLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard
          let flag = arguments.firstIndex(of: Self.launchArgument),
          arguments.index(after: flag) < arguments.endIndex,
          let scenario = VirtualIDCard.Scenario(
            rawValue: arguments[arguments.index(after: flag)])
        else {
          return
        }
        activate(scenario: scenario)
      }
    #endif

    internal func replace(with snapshot: VirtualIDCard.Snapshot) {
      state = snapshot
      card = VirtualIDCard(snapshot: snapshot)
      publishState()
    }

    internal func reset(to scenario: VirtualIDCard.Scenario) {
      state = scenario.snapshot
      card = VirtualIDCard(snapshot: state)
      publishState()
    }

    internal func forgetIdentity() {
      state.device = VirtualIDCard.DeviceState()
      card = VirtualIDCard(snapshot: state)
      publishState()
    }

    internal func connectionSnapshot(
      cardAccessNumber: String
    ) async -> CardMaintenance.ConnectionSnapshotResult {
      let result = await card.connect(cardAccessNumber: cardAccessNumber)
      let latest = await synchronizeFromCard()
      switch result {
      case .connected:
        return .connected(Self.maintenanceSnapshot(from: latest))

      case .incorrectCardAccessNumber:
        return .wrongCardAccessNumber

      case .unavailable:
        return .failed
      }
    }

    internal func maintenanceSnapshot() async -> CardMaintenance.Snapshot? {
      let probe = await card.probeCredentials()
      let latest = await synchronizeFromCard()
      switch probe {
      case .report(let report):
        return Self.maintenanceSnapshot(from: latest, retryReport: report)

      case .unreadable:
        return Self.maintenanceSnapshot(
          from: latest,
          report: CredentialProbeReport(
            pin1: .noInformation,
            pin2: .noInformation,
            puk: .noInformation))

      case .unavailable:
        return nil
      }
    }

    internal func credentialReport() async -> CredentialProbeReport? {
      let probe = await card.probeCredentials()
      _ = await synchronizeFromCard()
      switch probe {
      case .report(let report):
        return Self.report(from: report)

      case .unreadable:
        return CredentialProbeReport(
          pin1: .noInformation,
          pin2: .noInformation,
          puk: .noInformation)

      case .unavailable:
        return nil
      }
    }

    internal func readerActivationScheme() -> ActivationScheme? {
      guard isReaderCardPresent else { return nil }
      return activationScheme
    }

    internal func changePIN1(
      current: String,
      new: String
    ) async -> CardMaintenance.MutationReport {
      await mutation(await card.changePIN1(current: current, new: new))
    }

    internal func changePIN2(
      current: String,
      new: String
    ) async -> CardMaintenance.MutationReport {
      await mutation(await card.changePIN2(current: current, new: new))
    }

    internal func resetPIN1(
      puk: String,
      new: String
    ) async -> CardMaintenance.MutationReport {
      await mutation(await card.resetPIN1(puk: puk, new: new))
    }

    internal func resetPIN2(
      puk: String,
      new: String
    ) async -> CardMaintenance.MutationReport {
      await mutation(await card.resetPIN2(puk: puk, new: new))
    }

    internal func activateCard(
      request: CardMaintenance.ActivationRequest
    ) async -> CardMaintenance.ActivationExecution {
      let result = await card.activate(
        VirtualIDCard.ActivationRequest(
          entry: request.entry,
          newPIN1: request.newPin1,
          newPIN2: request.newPin2))
      let latest = await synchronizeFromCard()
      return CardMaintenance.ActivationExecution(
        activation: CardMaintenance.ActivationReport(
          scheme: Self.scheme(for: latest.card.generation),
          pin1: Self.outcome(from: result.pin1),
          pin2: result.pin2.map(Self.outcome(from:))),
        remaining: CardActivationNeeds(
          pin1: latest.card.pin1.isFactoryValue,
          pin2: latest.card.pin2.isFactoryValue))
    }

    internal func authenticate(
      pin1: String
    ) async -> VirtualIDCard.AuthenticationResult {
      let result = await card.authenticate(pin1: pin1)
      _ = await synchronizeFromCard()
      return result
    }

    internal func authorizeQualifiedSignature(
      pin2: String
    ) async -> VirtualIDCard.SignatureResult {
      let result = await card.authorizeQualifiedSignature(pin2: pin2)
      _ = await synchronizeFromCard()
      return result
    }

    private func mutation(
      _ result: VirtualIDCard.MutationResult
    ) async -> CardMaintenance.MutationReport {
      let latest = await synchronizeFromCard()
      let outcome = Self.outcome(from: result.outcome)
      let snapshot: CardMaintenance.Snapshot?
      if case .transportFailure = result.outcome {
        snapshot = nil
      } else {
        snapshot = Self.maintenanceSnapshot(from: latest)
      }
      return CardMaintenance.MutationReport(
        outcome: outcome,
        snapshot: snapshot)
    }

    @discardableResult
    private func synchronizeFromCard() async -> VirtualIDCard.Snapshot {
      let latest = await card.inspect()
      state = latest
      publishState()
      return latest
    }

    private func publishState() {
      revision &+= 1
      if state.card.cardPresent, !activationNeeds.any {
        CredentialRetryHealth.shared.update(
          Self.report(from: state.card))
      } else {
        CredentialRetryHealth.shared.clear()
      }
    }
  }

#endif
