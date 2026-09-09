// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: EUPL-1.2

import Foundation

/// Pure transition engine for the iOS card-setup and card-operation flow.
///
/// `Documentation/card-setup-state-machine.scxml` is the canonical grammar.
/// Keep `transitions` structurally identical to that document; exhaustive tests
/// reject any difference between the two representations.
internal enum CardSetupStateMachine {
  // State and Event are transcribed from the SCXML grammar in document
  // order, and exhaustive tests compare the two representations case by
  // case. Sorting them by name would break that correspondence.
  internal enum State: String, CaseIterable, Sendable {
    case activationHome = "activationHome"
    case activationIdentity = "activationIdentity"
    case classifyingBrowser = "classifyingBrowser"
    case classifyingManagementHome = "classifyingManagementHome"
    case classifyingManagementIdentity = "classifyingManagementIdentity"
    case documentSigningHome = "documentSigningHome"
    case documentSigningIdentity = "documentSigningIdentity"
    case home = "home"
    case identityHome = "identityHome"
    case pinManagementHome = "pinManagementHome"
    case pinManagementIdentity = "pinManagementIdentity"
    case registeringBrowser = "registeringBrowser"

    internal var destination: CardSetupStateMachine.Destination? {
      switch self {
      case .activationHome, .activationIdentity:
        .activation

      case .pinManagementHome, .pinManagementIdentity:
        .pinManagement

      case .documentSigningHome, .documentSigningIdentity:
        .signDocuments

      case .home, .identityHome, .classifyingBrowser, .classifyingManagementHome,
        .classifyingManagementIdentity, .registeringBrowser:
        nil
      }
    }
  }

  internal enum Event: String, CaseIterable, Sendable {
    case activationSucceeded = "activation.succeeded"
    case classificationActivated = "classification.activated"
    case classificationActivationRequired = "classification.activation-required"
    case classificationFailed = "classification.failed"
    case classificationRecoveryRequired = "classification.recovery-required"
    case classificationWrongCardAccessNumber = "classification.wrong-can"
    case destinationDismissed = "destination.dismissed"
    case identityForgotten = "identity.forgotten"
    case identityLoaded = "identity.loaded"
    case openDocumentSigning = "signing.open"
    case openKnownActivation = "activation.open.known"
    case openVerifiedManagement = "management.open.verified"
    case registrationFailed = "registration.failed"
    case registrationSucceeded = "registration.succeeded"
    case startBrowserClassification = "browser.classification.start"
    case startConfiguredBrowserRegistration = "browser.registration.start"
    case startManagementClassification = "management.classification.start"
  }

  internal enum Destination: Hashable, Sendable {
    case activation
    case pinManagement
    case signDocuments
  }

  internal struct Transition: Hashable, Sendable {
    internal let source: State
    internal let event: Event
    internal let target: State
  }

  internal enum Reduction: Equatable, Sendable {
    case rejected
    case transitioned(target: State)
  }

  internal static let initialState = State.home

  /// Executable mirror of the canonical SCXML transition grammar.
  ///
  /// An absent `(state, event)` pair is an explicit rejection. There are no
  /// implicit self-transitions and no timing-based transitions.
  internal static let transitions: [Transition] = [
    .init(source: .home, event: .identityLoaded, target: .identityHome),
    .init(source: .home, event: .startBrowserClassification, target: .classifyingBrowser),
    .init(source: .home, event: .startConfiguredBrowserRegistration, target: .registeringBrowser),
    .init(source: .home, event: .startManagementClassification, target: .classifyingManagementHome),
    .init(source: .home, event: .openKnownActivation, target: .activationHome),
    .init(source: .home, event: .openVerifiedManagement, target: .pinManagementHome),
    .init(source: .home, event: .openDocumentSigning, target: .documentSigningHome),

    .init(source: .identityHome, event: .identityForgotten, target: .home),
    .init(
      source: .identityHome, event: .startManagementClassification,
      target: .classifyingManagementIdentity),
    .init(source: .identityHome, event: .openKnownActivation, target: .activationIdentity),
    .init(source: .identityHome, event: .openVerifiedManagement, target: .pinManagementIdentity),
    .init(source: .identityHome, event: .openDocumentSigning, target: .documentSigningIdentity),

    .init(
      source: .classifyingBrowser, event: .classificationActivated, target: .registeringBrowser),
    .init(
      source: .classifyingBrowser, event: .classificationRecoveryRequired,
      target: .pinManagementHome),
    .init(
      source: .classifyingBrowser, event: .classificationActivationRequired, target: .activationHome
    ),
    .init(source: .classifyingBrowser, event: .classificationWrongCardAccessNumber, target: .home),
    .init(source: .classifyingBrowser, event: .classificationFailed, target: .home),

    .init(
      source: .classifyingManagementHome, event: .classificationActivated,
      target: .pinManagementHome),
    .init(
      source: .classifyingManagementHome, event: .classificationRecoveryRequired,
      target: .pinManagementHome),
    .init(
      source: .classifyingManagementHome, event: .classificationActivationRequired,
      target: .activationHome),
    .init(
      source: .classifyingManagementHome, event: .classificationWrongCardAccessNumber, target: .home
    ),
    .init(source: .classifyingManagementHome, event: .classificationFailed, target: .home),

    .init(
      source: .classifyingManagementIdentity, event: .classificationActivated,
      target: .pinManagementIdentity),
    .init(
      source: .classifyingManagementIdentity, event: .classificationRecoveryRequired,
      target: .pinManagementIdentity),
    .init(
      source: .classifyingManagementIdentity, event: .classificationActivationRequired,
      target: .activationIdentity),
    .init(
      source: .classifyingManagementIdentity, event: .classificationWrongCardAccessNumber,
      target: .identityHome),
    .init(
      source: .classifyingManagementIdentity, event: .classificationFailed, target: .identityHome),

    .init(source: .registeringBrowser, event: .registrationSucceeded, target: .identityHome),
    .init(source: .registeringBrowser, event: .registrationFailed, target: .home),

    .init(source: .activationHome, event: .activationSucceeded, target: .home),
    .init(source: .activationHome, event: .destinationDismissed, target: .home),
    .init(source: .activationIdentity, event: .activationSucceeded, target: .identityHome),
    .init(source: .activationIdentity, event: .destinationDismissed, target: .identityHome),

    .init(source: .pinManagementHome, event: .destinationDismissed, target: .home),
    .init(source: .pinManagementIdentity, event: .destinationDismissed, target: .identityHome),
    .init(source: .documentSigningHome, event: .destinationDismissed, target: .home),
    .init(source: .documentSigningIdentity, event: .destinationDismissed, target: .identityHome),
  ]

  internal static func reduce(state: State, event: Event) -> Reduction {
    let matches = transitions.lazy.filter { $0.source == state && $0.event == event }
    guard let transition = matches.first else {
      return .rejected
    }
    precondition(matches.dropFirst().isEmpty, "Ambiguous card-setup transition")
    return .transitioned(target: transition.target)
  }
}
