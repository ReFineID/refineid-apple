// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

@MainActor
internal final class CardManagementModel: ObservableObject {
  @Published internal private(set) var report: CredentialProbeReport? {
    didSet { CredentialRetryHealth.shared.update(report) }
  }
  @Published internal private(set) var activationNeeds = CardMaintenance.ActivationNeeds(
    pin1: true,
    pin2: true
  )
  @Published internal private(set) var activationScheme: ActivationScheme?
  @Published internal private(set) var offersActivation = false
  @Published internal private(set) var working = false
  @Published internal private(set) var failure: String?
  @Published internal private(set) var notice: String?

  private let activationRequired: Bool
  private var nextRefreshIdentifier = 0
  private var activeRefreshIdentifier: Int?

  internal var cardOperationInProgress: Bool {
    working || activeRefreshIdentifier != nil
  }

  @Published internal var transport: CardMaintenance.Transport {
    didSet {
      guard transport != oldValue else { return }
      #if DEBUG
        DebugConsole.emit(
          "card-management: transport changed from \(oldValue) to \(transport); clearing activation offer"
        )
      #endif
      activeRefreshIdentifier = nil
      report = nil
      if !activationRequired {
        activationScheme = nil
        offersActivation = false
      }
      failure = nil
      notice = nil
    }
  }

  @Published internal var cardAccessNumber: String
  internal let availableTransports = CardMaintenance.availableTransports

  internal var canContactCard: Bool {
    transport == .reader
      || cardAccessNumber.count == CardAccessNumber.digitCount
  }

  private var offeredCardAccessNumber: String? {
    transport == .nearField ? cardAccessNumber : nil
  }

  private var unreadableCardMessage: String {
    transport == .nearField
      ? "The card could not be read over NFC. Check its card access number and try again."
      : "No readable card. Connect a reader and insert the card."
  }

  internal init(
    transport: CardMaintenance.Transport? = nil,
    activationRequired: Bool = false,
    cardAccessNumber: String? = nil,
    activationScheme: ActivationScheme? = nil,
    activationNeeds: CardActivationNeeds? = nil
  ) {
    self.activationRequired = activationRequired
    self.transport = transport ?? CardMaintenance.preferredTransport
    self.activationScheme = activationScheme
    if let activationNeeds {
      self.activationNeeds = activationNeeds
      offersActivation = activationRequired && activationNeeds.any
    } else {
      offersActivation = activationRequired
    }
    self.cardAccessNumber =
      cardAccessNumber ?? CardCredentialStore.displayedCardAccessNumber() ?? ""
    #if DEBUG
      DebugConsole.emit(
        "card-management: initialized activationRequired=\(activationRequired) "
          + "needs=\(String(describing: activationNeeds)) "
          + "offersActivation=\(offersActivation) transport=\(self.transport)"
      )
    #endif
  }

  internal func cardRemoved() {
    #if DEBUG
      DebugConsole.emit("card-management: card removed; clearing activation offer")
    #endif
    activeRefreshIdentifier = nil
    report = nil
    if !activationRequired {
      activationScheme = nil
      offersActivation = false
    }
    failure = nil
    notice = nil
  }

  /// Reads only the card generation needed to validate an activation PIN.
  ///
  /// No retry counter is queried and the form remains interactive while
  /// the ATR or certificate classification completes.
  internal func detectActivationScheme() async {
    guard activationRequired || offersActivation, transport == .reader else { return }
    let detected = await CardMaintenance.readerActivationScheme()
    guard activationRequired || offersActivation, transport == .reader else { return }
    activationScheme = detected
  }

  internal func refresh() async {
    guard !cardOperationInProgress, canContactCard else { return }
    #if DEBUG
      DebugConsole.emit(
        "card-management: refresh started; offersActivation=\(offersActivation) transport=\(transport)"
      )
    #endif
    nextRefreshIdentifier &+= 1
    let refreshIdentifier = nextRefreshIdentifier
    activeRefreshIdentifier = refreshIdentifier
    failure = nil
    notice = nil
    let result = await CardMaintenance.snapshot(
      transport: transport,
      cardAccessNumber: offeredCardAccessNumber
    )
    guard activeRefreshIdentifier == refreshIdentifier else { return }
    activeRefreshIdentifier = nil
    guard let result else {
      #if DEBUG
        DebugConsole.emit("card-management: refresh failed; clearing activation offer")
      #endif
      report = nil
      if !activationRequired {
        offersActivation = false
      }
      failure = unreadableCardMessage
      return
    }
    apply(result)
  }

  /// Removes feedback that belongs to the previously selected operation.
  internal func clearOutcome() {
    failure = nil
    notice = nil
  }

  internal func changePin1(current: String, new: String) async -> Bool {
    await perform(presenting: "PIN 1", accepted: "PIN 1 changed") {
      await CardMaintenance.changePin1(
        current: current,
        new: new,
        transport: transport,
        cardAccessNumber: offeredCardAccessNumber
      )
    }
  }

  internal func changePin2(current: String, new: String) async -> Bool {
    await perform(presenting: "PIN 2", accepted: "PIN 2 changed") {
      await CardMaintenance.changePin2(
        current: current,
        new: new,
        transport: transport,
        cardAccessNumber: offeredCardAccessNumber
      )
    }
  }

  internal func unblock(target: CredentialRole, puk: String, new: String) async -> Bool {
    let accepted =
      target == .pin2
      ? "PIN 2 reset"
      : "PIN 1 reset"
    return await perform(presenting: "PUK", accepted: accepted) {
      if target == .pin2 {
        return await CardMaintenance.unblockPin2(
          puk: puk,
          new: new,
          transport: transport,
          cardAccessNumber: offeredCardAccessNumber
        )
      }
      return await CardMaintenance.unblockPin1(
        puk: puk,
        new: new,
        transport: transport,
        cardAccessNumber: offeredCardAccessNumber
      )
    }
  }

  internal func activate(
    entry: String,
    newPin1: String?,
    newPin2: String?
  ) async -> Bool {
    guard beginCardOperation() else { return false }
    guard let scheme = activationScheme else {
      failure = "The card could not be classified for activation."
      return false
    }
    working = true
    failure = nil
    notice = nil
    let execution = await CardMaintenance.activate(
      request: CardMaintenance.ActivationRequest(
        entry: entry,
        newPin1: newPin1,
        newPin2: newPin2,
        scheme: scheme,
        needs: activationNeeds
      ),
      transport: transport,
      cardAccessNumber: offeredCardAccessNumber
    )
    working = false
    guard let execution else {
      failure = "The card could not be classified for activation."
      return false
    }
    _ = describe(execution.activation)
    activationNeeds = execution.remaining
    offersActivation = execution.remaining.any
    return !execution.remaining.any
  }

  private func apply(
    _ snapshot: CardMaintenance.Snapshot,
    preservingOutcome: Bool = false
  ) {
    report = snapshot.report
    activationScheme = snapshot.activationScheme
    if let needs = snapshot.activationNeeds {
      activationNeeds = needs
      offersActivation = needs.any
    } else {
      offersActivation = false
    }
    #if DEBUG
      DebugConsole.emit(
        "card-management: applied snapshot needs=\(String(describing: snapshot.activationNeeds)) "
          + "offersActivation=\(offersActivation)"
      )
    #endif
    if !preservingOutcome {
      failure = nil
      notice = nil
    }
  }

  private func describe(_ activation: CardMaintenance.ActivationReport) -> Bool {
    let entry = activationEntryName(activation.scheme)
    switch (activation.pin1, activation.pin2) {
    case (.success, .success):
      notice = "Card activated: PIN 1 and PIN 2 are set"
      return true

    case (.alreadyActivated, .success):
      notice = "Card activated: PIN 2 is set; PIN 1 already was"
      return true

    case (.success, .alreadyActivated), (.success, nil):
      notice = "Card activated: PIN 1 is set; PIN 2 already was"
      return true

    case (.success, .some(let second)):
      failure = message(for: second, presenting: entry)
        .map { "PIN 1 was set, but PIN 2 was not: \($0)" }
      return false

    case (.alreadyActivated, .some(let second)):
      failure = message(for: second, presenting: entry)
        .map { "PIN 2 was not set: \($0)" }
      return false

    case (.alreadyActivated, nil):
      failure = "This card is already activated."
      return false

    case (let first, _):
      failure = message(for: first, presenting: entry)
      return false
    }
  }

  private func activationEntryName(_ scheme: ActivationScheme) -> String {
    switch scheme {
    case .activationCodeIsPuk:
      "activation code"

    case .presetActivationPin:
      "activation PIN"
    }
  }

  private func perform(
    presenting: String,
    accepted: String,
    _ operation: () async -> CardMaintenance.MutationReport
  ) async -> Bool {
    guard beginCardOperation() else { return false }
    working = true
    failure = nil
    notice = nil
    let mutation = await operation()
    working = false
    if mutation.outcome == .success {
      notice = accepted
    } else {
      failure = message(for: mutation.outcome, presenting: presenting)
    }
    if let snapshot = mutation.snapshot {
      apply(snapshot, preservingOutcome: true)
    }
    return mutation.outcome == .success
  }

  /// Starts a mutating card operation or explains why it could not start.
  ///
  /// Buttons mirror these conditions, but confirmation is asynchronous: card
  /// removal or an event-driven refresh can happen while the system alert is
  /// visible. A confirmed operation must never disappear as a silent no-op.
  private func beginCardOperation() -> Bool {
    if cardOperationInProgress {
      failure = "Another card operation is still in progress. Try again."
      return false
    }
    guard canContactCard else {
      failure = unreadableCardMessage
      return false
    }
    return true
  }

  private func message(
    for outcome: CardMaintenance.Outcome,
    presenting: String
  ) -> String? {
    switch outcome {
    case .success:
      nil

    case .invalidEntry:
      "The entry does not fit the credential's digit rules."

    case .noCard:
      unreadableCardMessage

    case .floorRefused(.refuseBlocked), .pinBlocked:
      "\(presenting) is blocked."

    case .floorRefused(.refuseLowAttempts):
      CredentialOutcomeMessage.lowAttemptRefusal()

    case .floorRefused:
      "The \(presenting) retry counter could not be read; nothing was sent."

    case .rejected(let remaining):
      CredentialOutcomeMessage.rejection(
        credentialName: presenting,
        remaining: remaining)

    case .invalidated:
      "The credential slot is invalidated; only the issuer can recover it."

    case .alreadyActivated:
      "This card looks activated already."

    case .failed:
      "The card operation did not complete."
    }
  }
}
