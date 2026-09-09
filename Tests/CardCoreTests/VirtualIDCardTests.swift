// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import XCTest

internal final class VirtualIDCardTests: XCTestCase {
  internal func testWrongCardAccessNumberDoesNotConfigureDevice() async {
    let card = VirtualIDCard(scenario: .activatedNearField)

    let result = await card.connect(cardAccessNumber: "000000")
    let state = await card.inspect()

    XCTAssertEqual(result, .incorrectCardAccessNumber)
    XCTAssertNil(state.device.connectedCardAccessNumber)
    XCTAssertNil(state.device.storedCardAccessNumber)
  }

  internal func testActivatedCardStoresValidatedCardAccessNumber() async {
    let card = VirtualIDCard(scenario: .activatedNearField)

    _ = await card.connect(cardAccessNumber: "123456")
    let state = await card.inspect()

    XCTAssertEqual(state.device.storedCardAccessNumber, "123456")
  }

  internal func testConnectionClassificationDoesNotReadCertificates() async {
    var state = VirtualIDCard.Scenario.factoryFreshNearField.snapshot
    state.card.authenticationCertificate = .missing
    state.card.signatureCertificate = .unreadable
    let card = VirtualIDCard(snapshot: state)

    let result = await card.connect(cardAccessNumber: "123456")

    guard case .connected(let connected) = result else {
      XCTFail("connection classification depended on a certificate")
      return
    }
    XCTAssertTrue(connected.card.pin1.isFactoryValue)
    XCTAssertTrue(connected.card.pin2.isFactoryValue)
  }

  internal func testFactoryCardDoesNotStoreCardAccessNumberBeforeActivation() async {
    let card = VirtualIDCard(scenario: .factoryFreshNearField)

    _ = await card.connect(cardAccessNumber: "123456")
    let state = await card.inspect()

    XCTAssertEqual(state.device.connectedCardAccessNumber, "123456")
    XCTAssertNil(state.device.storedCardAccessNumber)
  }

  internal func testActivationChangesBothFactoryCredentialsIndependently() async {
    let card = VirtualIDCard(scenario: .factoryFreshNearField)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: "4567",
        newPIN2: "654321"))

    XCTAssertEqual(result.pin1, .success)
    XCTAssertEqual(result.pin2, .success)
    XCTAssertFalse(result.snapshot.card.pin1.isFactoryValue)
    XCTAssertFalse(result.snapshot.card.pin2.isFactoryValue)
    XCTAssertEqual(result.snapshot.device.storedCardAccessNumber, "123456")
  }

  internal func testLostReplyAfterPIN1LeavesOnlyPIN2InFactoryState() async {
    var scenario = VirtualIDCard.Scenario.factoryFreshNearField.snapshot
    scenario.faults =
      VirtualIDCard.FaultPreset.responseLostAfterPIN1Activation.faults
    let card = VirtualIDCard(snapshot: scenario)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: "4567",
        newPIN2: "654321"))

    XCTAssertEqual(
      result.pin1,
      .transportFailure(.connectionLost))
    XCTAssertFalse(result.snapshot.card.pin1.isFactoryValue)
    XCTAssertTrue(result.snapshot.card.pin2.isFactoryValue)
  }

  internal func testPartialActivationContinuesWithOnlyPIN2() async {
    let card = VirtualIDCard(scenario: .partialActivationNearField)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: nil,
        newPIN2: "654321"))

    XCTAssertEqual(result.pin1, .alreadyActivated)
    XCTAssertEqual(result.pin2, .success)
    XCTAssertFalse(result.snapshot.card.pin1.isFactoryValue)
    XCTAssertFalse(result.snapshot.card.pin2.isFactoryValue)
    XCTAssertEqual(result.snapshot.device.storedCardAccessNumber, "123456")
  }

  internal func testNonDigitActivationEntryDoesNotSpendAttempt() async {
    let card = VirtualIDCard(scenario: .factoryFreshNearField)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "abcdefg",
        newPIN1: "4567",
        newPIN2: "654321"))

    XCTAssertEqual(result.pin1, .invalidEntry)
    XCTAssertEqual(
      result.snapshot.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testWrongPINDecrementsOnlyItsOwnCounter() async {
    let card = VirtualIDCard(scenario: .activatedNearField)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.changePIN1(current: "0000", new: "9876")

    XCTAssertEqual(result.outcome, .rejected(remaining: 4))
    XCTAssertEqual(result.snapshot.card.pin1.attemptsRemaining, 4)
    XCTAssertEqual(
      result.snapshot.card.pin2.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testLastTwoAttemptsAreNeverSpent() async {
    let card = VirtualIDCard(scenario: .pin1RecoveryReader)

    let result = await card.changePIN1(current: "0000", new: "9876")

    XCTAssertEqual(result.outcome, .refusedLowAttempts(remaining: 2))
    XCTAssertEqual(result.snapshot.card.pin1.attemptsRemaining, 2)
  }

  internal func testPIN1RetryFloorMatrix() async {
    for attempts in UInt8(0)...RetryCount.pristineAllowance {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.card.pin1.attemptsRemaining = attempts
      let card = VirtualIDCard(snapshot: state)

      let result = await card.changePIN1(current: "0000", new: "9876")

      switch attempts {
      case 0:
        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(result.snapshot.card.pin1.attemptsRemaining, 0)

      case 1, 2:
        XCTAssertEqual(
          result.outcome,
          .refusedLowAttempts(remaining: attempts))
        XCTAssertEqual(
          result.snapshot.card.pin1.attemptsRemaining,
          attempts)

      default:
        XCTAssertEqual(
          result.outcome,
          .rejected(remaining: attempts - 1))
        XCTAssertEqual(
          result.snapshot.card.pin1.attemptsRemaining,
          attempts - 1)
      }
    }
  }

  internal func testSafePUKCanResetBlockedPIN() async {
    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.card.pin1.attemptsRemaining = 0
    let card = VirtualIDCard(snapshot: state)

    let result = await card.resetPIN1(puk: "12345678", new: "9876")

    XCTAssertEqual(result.outcome, .success)
    XCTAssertEqual(
      result.snapshot.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
    XCTAssertEqual(result.snapshot.card.pin1.value, "9876")
  }

  internal func testPUKFloorRefusesResetWithoutChangingCard() async {
    let card = VirtualIDCard(scenario: .pukRecoveryRefusedReader)

    let result = await card.resetPIN1(puk: "12345678", new: "9876")

    XCTAssertEqual(result.outcome, .refusedLowAttempts(remaining: 2))
    XCTAssertEqual(result.snapshot.card.pin1.attemptsRemaining, 0)
    XCTAssertEqual(result.snapshot.card.puk.attemptsRemaining, 2)
  }

  internal func testFaultBeforeCommandDoesNotMutateCredential() async {
    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.faults =
      VirtualIDCard.FaultPreset.cardRemovedDuringPINChange.faults
    let card = VirtualIDCard(snapshot: state)

    let result = await card.changePIN1(current: "1234", new: "9876")

    XCTAssertEqual(result.outcome, .transportFailure(.cardRemoved))
    XCTAssertEqual(result.snapshot.card.pin1.value, "1234")
    XCTAssertFalse(result.snapshot.card.cardPresent)
  }

  internal func testFaultAfterCommandPreservesCardMutation() async {
    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.faults = [
      VirtualIDCard.Fault(
        operation: .changePIN1,
        phase: .afterCardExecution,
        effect: .timeout)
    ]
    let card = VirtualIDCard(snapshot: state)

    let result = await card.changePIN1(current: "1234", new: "9876")

    XCTAssertEqual(result.outcome, .transportFailure(.timeout))
    XCTAssertEqual(result.snapshot.card.pin1.value, "9876")
    XCTAssertEqual(
      result.snapshot.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testForgettingIdentityChangesOnlyDeviceState() async {
    let card = VirtualIDCard(scenario: .registeredNearField)
    let original = await card.inspect().card

    await card.forgetDeviceState()
    let forgotten = await card.inspect()

    XCTAssertEqual(forgotten.card, original)
    XCTAssertEqual(forgotten.device, VirtualIDCard.DeviceState())
  }

  internal func testSuccessfulAuthenticationPublishesOnlyVirtualDeviceState() async {
    let card = VirtualIDCard(scenario: .activatedNearField)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.authenticate(pin1: "1234")

    guard case .success(let state) = result else {
      XCTFail("authentication did not succeed")
      return
    }
    XCTAssertTrue(state.device.hasPin1)
    XCTAssertTrue(state.device.cachedIdentity)
    XCTAssertTrue(state.device.tokenRegistered)
  }

  internal func testEveryScenarioAndFaultPresetBuildsDeterministicState() {
    for scenario in VirtualIDCard.Scenario.allCases {
      let first = scenario.snapshot
      let second = scenario.snapshot

      XCTAssertEqual(first, second, "\(scenario.rawValue) was not deterministic")
      XCTAssertLessThanOrEqual(
        first.card.pin1.attemptsRemaining,
        RetryCount.pristineAllowance)
      XCTAssertLessThanOrEqual(
        first.card.pin2.attemptsRemaining,
        RetryCount.pristineAllowance)
      XCTAssertLessThanOrEqual(
        first.card.puk.attemptsRemaining,
        RetryCount.pristineAllowance)
    }

    for preset in VirtualIDCard.FaultPreset.allCases {
      if preset == .noFault {
        XCTAssertTrue(preset.faults.isEmpty)
      } else {
        XCTAssertFalse(preset.faults.isEmpty, "\(preset.rawValue) has no fault")
      }
    }
  }

  internal func testStateReplacementResetAndFaultQueueControls() async {
    let card = VirtualIDCard()
    let initial = await card.inspect()
    XCTAssertEqual(
      initial,
      VirtualIDCard.Scenario.factoryFreshNearField.snapshot)

    await card.replace(with: VirtualIDCard.Scenario.registeredNearField.snapshot)
    let registered = await card.inspect()
    XCTAssertTrue(registered.device.tokenRegistered)

    await card.reset(to: .absent)
    let absent = await card.inspect()
    XCTAssertFalse(absent.card.cardPresent)

    await card.enqueue(
      VirtualIDCard.Fault(
        operation: .any,
        phase: .beforeCommand,
        effect: .timeout,
        remainingOccurrences: 0))
    let enqueued = await card.inspect()
    XCTAssertEqual(enqueued.faults.first?.remainingOccurrences, 1)

    await card.clearFaults()
    let cleared = await card.inspect()
    XCTAssertTrue(cleared.faults.isEmpty)
  }

  internal func testConnectionFailureClearsTransientStateAndDoesNotPersistCAN() async {
    let card = VirtualIDCard(scenario: .activatedNearField)
    _ = await card.connect(cardAccessNumber: "123456")
    var state = await card.inspect()
    state.card.cardPresent = false
    await card.replace(with: state)

    let removedConnection = await card.connect(cardAccessNumber: "123456")
    XCTAssertEqual(removedConnection, .unavailable(.cardRemoved))
    let removedState = await card.inspect()
    XCTAssertNil(removedState.device.connectedCardAccessNumber)

    state = VirtualIDCard.Scenario.activatedNearField.snapshot
    state.faults = [
      VirtualIDCard.Fault(
        operation: .connect,
        phase: .afterCardExecution,
        effect: .timeout)
    ]
    await card.replace(with: state)

    let timedOutConnection = await card.connect(cardAccessNumber: "123456")
    XCTAssertEqual(timedOutConnection, .unavailable(.timeout))
    let failed = await card.inspect()
    XCTAssertNil(failed.device.connectedCardAccessNumber)
    XCTAssertNil(failed.device.storedCardAccessNumber)

    await card.reset(to: .activatedReader)
    guard case .connected = await card.connect(cardAccessNumber: "not-a-CAN") else {
      XCTFail("reader connection incorrectly required a wireless CAN")
      return
    }
    let reader = await card.inspect()
    XCTAssertNil(reader.device.connectedCardAccessNumber)
    XCTAssertNil(reader.device.storedCardAccessNumber)
  }

  internal func testMalformedCANAndDisconnectedReaderAreUnavailableSafely() async {
    for offered in ["", "12345", "1234567", "12a456"] {
      let card = VirtualIDCard(scenario: .activatedNearField)
      let result = await card.connect(cardAccessNumber: offered)
      XCTAssertEqual(result, .incorrectCardAccessNumber)
      let state = await card.inspect()
      XCTAssertEqual(state.device, VirtualIDCard.DeviceState())
    }

    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.card.readerConnected = false
    state.device.connectedCardAccessNumber = "stale"
    let card = VirtualIDCard(snapshot: state)
    let result = await card.connect(cardAccessNumber: "")
    XCTAssertEqual(result, .unavailable(.readerDisconnected))
    let disconnected = await card.inspect()
    XCTAssertNil(disconnected.device.connectedCardAccessNumber)
  }

  internal func testCredentialProbeCoversReportsAndFailures() async {
    let reporting = VirtualIDCard(scenario: .activatedReader)
    let report = await reporting.probeCredentials()
    XCTAssertEqual(
      report,
      .report(
        VirtualIDCard.RetryReport(
          pin1: RetryCount.pristineAllowance,
          pin2: RetryCount.pristineAllowance,
          puk: RetryCount.pristineAllowance)))

    let disconnected = VirtualIDCard(scenario: .activatedNearField)
    let disconnectedResult = await disconnected.probeCredentials()
    XCTAssertEqual(disconnectedResult, .unavailable(.connectionLost))

    for phase in VirtualIDCard.FaultPhase.allCases {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.faults = [
        VirtualIDCard.Fault(
          operation: .probeCredentials,
          phase: phase,
          effect: .malformedResponse)
      ]
      let unreadable = VirtualIDCard(snapshot: state)
      let result = await unreadable.probeCredentials()
      XCTAssertEqual(result, .unreadable)
    }

    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.faults = VirtualIDCard.FaultPreset.readerFailsCounterQuery.faults
    let failedReader = VirtualIDCard(snapshot: state)
    let failure = await failedReader.probeCredentials()
    XCTAssertEqual(failure, .unavailable(.readerDisconnected))
    let failedState = await failedReader.inspect()
    XCTAssertFalse(failedState.card.readerConnected)
    XCTAssertFalse(failedState.card.cardPresent)
  }

  internal func testMalformedPINChangeNeverConsumesRetryOrFault() async {
    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.faults = [
      VirtualIDCard.Fault(
        operation: .changePIN1,
        phase: .beforeCommand,
        effect: .timeout)
    ]
    let card = VirtualIDCard(snapshot: state)

    let malformedCurrent = await card.changePIN1(current: "bad", new: "9876")
    XCTAssertEqual(malformedCurrent.outcome, .invalidEntry)
    let unchanged = await card.changePIN1(current: "1234", new: "1234")
    XCTAssertEqual(unchanged.outcome, .invalidEntry)
    let malformedNew = await card.changePIN2(
      current: "123456",
      new: "short")
    XCTAssertEqual(malformedNew.outcome, .invalidEntry)
    let untouched = await card.inspect()
    XCTAssertEqual(
      untouched.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
    XCTAssertEqual(untouched.faults.count, 1)

    let timedOut = await card.changePIN1(current: "1234", new: "9876")
    XCTAssertEqual(timedOut.outcome, .transportFailure(.timeout))
  }

  internal func testPIN2RetryFloorMatrix() async {
    for attempts in UInt8(0)...RetryCount.pristineAllowance {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.card.pin2.attemptsRemaining = attempts
      let card = VirtualIDCard(snapshot: state)

      let result = await card.changePIN2(current: "000000", new: "987654")

      switch attempts {
      case 0:
        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(result.snapshot.card.pin2.attemptsRemaining, 0)

      case 1, 2:
        XCTAssertEqual(result.outcome, .refusedLowAttempts(remaining: attempts))
        XCTAssertEqual(result.snapshot.card.pin2.attemptsRemaining, attempts)

      default:
        XCTAssertEqual(result.outcome, .rejected(remaining: attempts - 1))
        XCTAssertEqual(result.snapshot.card.pin2.attemptsRemaining, attempts - 1)
      }
    }
  }

  internal func testPUKRetryFloorMatrix() async {
    for attempts in UInt8(0)...RetryCount.pristineAllowance {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.card.pin1.attemptsRemaining = 0
      state.card.puk.attemptsRemaining = attempts
      let card = VirtualIDCard(snapshot: state)

      let result = await card.resetPIN1(puk: "00000000", new: "9876")

      switch attempts {
      case 0:
        XCTAssertEqual(result.outcome, .blocked)
        XCTAssertEqual(result.snapshot.card.puk.attemptsRemaining, 0)

      case 1, 2:
        XCTAssertEqual(result.outcome, .refusedLowAttempts(remaining: attempts))
        XCTAssertEqual(result.snapshot.card.puk.attemptsRemaining, attempts)

      default:
        XCTAssertEqual(result.outcome, .rejected(remaining: attempts - 1))
        XCTAssertEqual(result.snapshot.card.puk.attemptsRemaining, attempts - 1)
      }
      XCTAssertEqual(result.snapshot.card.pin1.attemptsRemaining, 0)
    }
  }

  internal func testPIN2ChangeAndResetUseTheSameSafetyRules() async {
    let changing = VirtualIDCard(scenario: .activatedReader)
    let changed = await changing.changePIN2(current: "123456", new: "987654")
    XCTAssertEqual(changed.outcome, .success)
    XCTAssertEqual(changed.snapshot.card.pin2.value, "987654")

    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.card.pin2.attemptsRemaining = 0
    let resetting = VirtualIDCard(snapshot: state)
    let reset = await resetting.resetPIN2(puk: "12345678", new: "987654")
    XCTAssertEqual(reset.outcome, .success)
    XCTAssertEqual(reset.snapshot.card.pin2.value, "987654")
    XCTAssertEqual(
      reset.snapshot.card.pin2.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testMalformedResetInputDoesNotSpendPUK() async {
    for input in [
      (puk: "123", pin: "9876"),
      (puk: "notdigits", pin: "9876"),
      (puk: "12345678", pin: "12"),
    ] {
      let card = VirtualIDCard(scenario: .activatedReader)
      let result = await card.resetPIN1(puk: input.puk, new: input.pin)
      XCTAssertEqual(result.outcome, .invalidEntry)
      XCTAssertEqual(
        result.snapshot.card.puk.attemptsRemaining,
        RetryCount.pristineAllowance)
    }
  }

  internal func testActivationValidationAndAlreadyActivatedResult() async {
    let activated = VirtualIDCard(scenario: .activatedNearField)
    let alreadyActivated = await activated.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: "4567",
        newPIN2: "654321"))
    XCTAssertEqual(alreadyActivated.pin1, .alreadyActivated)

    let factory = VirtualIDCard(scenario: .factoryFreshNearField)
    _ = await factory.connect(cardAccessNumber: "123456")
    let missingPIN1 = await factory.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: nil,
        newPIN2: "654321"))
    XCTAssertEqual(missingPIN1.pin1, .invalidEntry)

    let partial = VirtualIDCard(scenario: .partialActivationNearField)
    _ = await partial.connect(cardAccessNumber: "123456")
    let missingPIN2 = await partial.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: nil,
        newPIN2: nil))
    XCTAssertEqual(missingPIN2.pin1, .alreadyActivated)
    XCTAssertEqual(missingPIN2.pin2, .invalidEntry)

    let legacy = VirtualIDCard(scenario: .legacyFactoryFreshNearField)
    _ = await legacy.connect(cardAccessNumber: "123456")
    let wrongLength = await legacy.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: "4567",
        newPIN2: "654321"))
    XCTAssertEqual(wrongLength.pin1, .invalidEntry)
    XCTAssertEqual(
      wrongLength.snapshot.card.puk.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testLegacyActivationUsesPUKWithoutCertificateReads() async {
    var state = VirtualIDCard.Scenario.legacyFactoryFreshNearField.snapshot
    state.card.authenticationCertificate = .unreadable
    state.card.signatureCertificate = .missing
    let card = VirtualIDCard(snapshot: state)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "12345678",
        newPIN1: "4567",
        newPIN2: "654321"))

    XCTAssertEqual(result.pin1, .success)
    XCTAssertEqual(result.pin2, .success)
    XCTAssertFalse(result.snapshot.card.pin1.isFactoryValue)
    XCTAssertFalse(result.snapshot.card.pin2.isFactoryValue)
    XCTAssertEqual(
      result.snapshot.card.puk.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testLostFinalActivationReplyRequiresSuccessfulReconnectBeforeCANStorage() async {
    var state = VirtualIDCard.Scenario.factoryFreshNearField.snapshot
    state.faults = VirtualIDCard.FaultPreset.responseLostAfterPIN2Activation.faults
    let card = VirtualIDCard(snapshot: state)
    _ = await card.connect(cardAccessNumber: "123456")

    let result = await card.activate(
      VirtualIDCard.ActivationRequest(
        entry: "1234567",
        newPIN1: "4567",
        newPIN2: "654321"))

    XCTAssertEqual(result.pin1, .success)
    XCTAssertEqual(result.pin2, .transportFailure(.connectionLost))
    XCTAssertFalse(result.snapshot.card.pin1.isFactoryValue)
    XCTAssertFalse(result.snapshot.card.pin2.isFactoryValue)
    XCTAssertNil(result.snapshot.device.storedCardAccessNumber)

    _ = await card.connect(cardAccessNumber: "123456")
    let reconnected = await card.inspect()
    XCTAssertEqual(reconnected.device.storedCardAccessNumber, "123456")
  }

  internal func testAuthenticationRetryFloorMatrix() async {
    for attempts in UInt8(0)...RetryCount.pristineAllowance {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.card.pin1.attemptsRemaining = attempts
      let card = VirtualIDCard(snapshot: state)

      let result = await card.authenticate(pin1: "0000")

      switch attempts {
      case 0:
        XCTAssertEqual(result, .blocked)

      case 1, 2:
        XCTAssertEqual(result, .refusedLowAttempts(remaining: attempts))

      default:
        XCTAssertEqual(result, .rejected(remaining: attempts - 1))
      }
      let inspected = await card.inspect()
      let expectedAttempts = attempts >= 3 ? attempts - 1 : attempts
      XCTAssertEqual(inspected.card.pin1.attemptsRemaining, expectedAttempts)
    }

    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.card.pin1.attemptsRemaining = 3
    let successful = VirtualIDCard(snapshot: state)
    guard case .success(let result) = await successful.authenticate(pin1: "1234")
    else {
      XCTFail("a safe correct PIN 1 was rejected")
      return
    }
    XCTAssertEqual(
      result.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testAuthenticationCertificateAndPublicationFailures() async {
    let malformed = VirtualIDCard(scenario: .activatedReader)
    let malformedResult = await malformed.authenticate(pin1: "12")
    XCTAssertEqual(malformedResult, .invalidEntry)

    for certificate in VirtualIDCard.CertificateState.allCases
    where certificate != .valid {
      var state = VirtualIDCard.Scenario.activatedReader.snapshot
      state.card.authenticationCertificate = certificate
      let card = VirtualIDCard(snapshot: state)
      let result = await card.authenticate(pin1: "1234")
      XCTAssertEqual(
        result,
        .certificateUnavailable,
        "\(certificate.rawValue) certificate was accepted")
    }

    var state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.card.signatureCertificate = .revoked
    state.faults = VirtualIDCard.FaultPreset.tokenPublicationFailure.faults
    let publication = VirtualIDCard(snapshot: state)
    guard
      case .tokenPublicationFailed(let failed) =
        await publication.authenticate(pin1: "1234")
    else {
      XCTFail("token publication fault was not surfaced")
      return
    }
    XCTAssertTrue(failed.device.hasPin1)
    XCTAssertTrue(failed.device.cachedIdentity)
    XCTAssertFalse(failed.device.tokenRegistered)

    state = VirtualIDCard.Scenario.activatedReader.snapshot
    state.faults = [
      VirtualIDCard.Fault(
        operation: .authenticate,
        phase: .afterCardExecution,
        effect: .timeout)
    ]
    let lostReply = VirtualIDCard(snapshot: state)
    let lostResult = await lostReply.authenticate(pin1: "1234")
    XCTAssertEqual(lostResult, .transportFailure(.timeout))
    let lostState = await lostReply.inspect()
    XCTAssertEqual(
      lostState.card.pin1.attemptsRemaining,
      RetryCount.pristineAllowance)
  }

  internal func testWildcardFaultRepeatsExactlyAsConfigured() async {
    let card = VirtualIDCard(scenario: .activatedNearField)
    await card.enqueue(
      VirtualIDCard.Fault(
        operation: .any,
        phase: .beforeCommand,
        effect: .timeout,
        remainingOccurrences: 2))

    let first = await card.connect(cardAccessNumber: "123456")
    XCTAssertEqual(first, .unavailable(.timeout))
    let onceRemaining = await card.inspect()
    XCTAssertEqual(onceRemaining.faults.first?.remainingOccurrences, 1)
    let second = await card.connect(cardAccessNumber: "123456")
    XCTAssertEqual(second, .unavailable(.timeout))
    let consumed = await card.inspect()
    XCTAssertTrue(consumed.faults.isEmpty)
    guard case .connected = await card.connect(cardAccessNumber: "123456") else {
      XCTFail("consumed wildcard fault remained active")
      return
    }
  }
}
