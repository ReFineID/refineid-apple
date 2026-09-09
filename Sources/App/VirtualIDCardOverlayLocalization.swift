// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import Foundation

  internal enum VirtualIDCardOverlayLocalization {
    internal static func localizedText(
      _ key: StaticString,
      defaultValue: String.LocalizationValue
    ) -> String {
      String(
        localized: key,
        defaultValue: defaultValue,
        table: "VirtualIDCard")
    }

    internal static func scenarioName(_ scenario: VirtualIDCard.Scenario) -> String {
      switch scenario {
      case .factoryFreshNearField:
        localizedText(
          "scenario.factoryFreshNearField",
          defaultValue: "Factory-fresh NFC card")

      case .legacyFactoryFreshNearField:
        localizedText(
          "scenario.legacyFactoryFreshNearField",
          defaultValue: "Factory-fresh legacy NFC card")

      case .partialActivationNearField:
        localizedText(
          "scenario.partialActivationNearField",
          defaultValue: "Partially activated NFC card")

      case .activatedNearField:
        localizedText("scenario.activatedNearField", defaultValue: "Activated NFC card")

      case .registeredNearField:
        localizedText("scenario.registeredNearField", defaultValue: "Registered NFC identity")

      case .factoryFreshReader:
        localizedText(
          "scenario.factoryFreshReader",
          defaultValue: "Factory-fresh reader card")

      case .activatedReader:
        localizedText("scenario.activatedReader", defaultValue: "Activated reader card")

      case .pin1RecoveryReader:
        localizedText("scenario.pin1RecoveryReader", defaultValue: "PIN 1 recovery with reader")

      case .pin2RecoveryReader:
        localizedText("scenario.pin2RecoveryReader", defaultValue: "PIN 2 recovery with reader")

      case .pukRecoveryRefusedReader:
        localizedText(
          "scenario.pukRecoveryRefusedReader",
          defaultValue: "PUK recovery refused with reader")

      case .absent:
        localizedText("scenario.absent", defaultValue: "No card")
      }
    }

    internal static func generationName(_ generation: VirtualIDCard.Generation) -> String {
      switch generation {
      case .activationCodeIsPuk:
        localizedText(
          "generation.activationCodeIsPuk",
          defaultValue: "Activation code is PUK")

      case .presetActivationPIN:
        localizedText(
          "generation.presetActivationPIN",
          defaultValue: "Separate activation PIN")
      }
    }

    internal static func certificateStateName(_ state: VirtualIDCard.CertificateState) -> String {
      switch state {
      case .valid:
        localizedText("certificate.valid", defaultValue: "Valid")

      case .expired:
        localizedText("certificate.expired", defaultValue: "Expired")

      case .revoked:
        localizedText("certificate.revoked", defaultValue: "Revoked")

      case .unreadable:
        localizedText("certificate.unreadable", defaultValue: "Unreadable")

      case .missing:
        localizedText("certificate.missing", defaultValue: "Missing")
      }
    }

    internal static func faultPresetName(_ preset: VirtualIDCard.FaultPreset) -> String {
      switch preset {
      case .noFault:
        localizedText("fault.none", defaultValue: "None")

      case .nfcDisconnectBeforeConnection:
        localizedText(
          "fault.nfcDisconnectBeforeConnection",
          defaultValue: "NFC disconnects before connection")

      case .readerFailsCounterQuery:
        localizedText(
          "fault.readerFailsCounterQuery",
          defaultValue: "Reader fails retry counter query")

      case .cardRemovedDuringPINChange:
        localizedText(
          "fault.cardRemovedDuringPINChange",
          defaultValue: "Card removed during PIN change")

      case .cardRemovedDuringSignature:
        localizedText(
          "fault.cardRemovedDuringSignature",
          defaultValue: "Card removed during document signing")

      case .responseLostAfterPIN1Activation:
        localizedText(
          "fault.responseLostAfterPIN1Activation",
          defaultValue: "Response lost after PIN 1 activation")

      case .responseLostAfterPIN2Activation:
        localizedText(
          "fault.responseLostAfterPIN2Activation",
          defaultValue: "Response lost after PIN 2 activation")

      case .responseLostAfterSignature:
        localizedText(
          "fault.responseLostAfterSignature",
          defaultValue: "Response lost after document signing")

      case .certificateReadFailure:
        localizedText("fault.certificateReadFailure", defaultValue: "Certificate read failure")

      case .tokenPublicationFailure:
        localizedText("fault.tokenPublicationFailure", defaultValue: "Token publication failure")
      }
    }
  }

#endif
