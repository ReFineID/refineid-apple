// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import XCTest

  /// Hardware-free journeys configured through the visible Virtual ID Card.
  @MainActor
  internal final class VirtualIDCardUITests: XCTestCase {
    private enum Destination {
      case cardAccessNumber
      case activation
      case readerIdentity
      case registeredIdentity
    }

    private struct CredentialJourney {
      let task: String
      let fields: [(identifier: String, value: String)]
      let action: String
      let outcome: String
    }

    private static let appearTimeout: TimeInterval = 10

    override internal func setUp() {
      super.setUp()
      continueAfterFailure = false
    }

    internal func testScenarioFactoryFreshNFCRoutesThroughGUI() {
      assertScenario("factory-fresh-nfc", destination: .cardAccessNumber)
    }

    internal func testScenarioLegacyFactoryFreshNFCRoutesThroughGUI() {
      assertScenario("legacy-factory-fresh-nfc", destination: .cardAccessNumber)
    }

    internal func testScenarioPartialActivationNFCRoutesThroughGUI() {
      assertScenario("partial-activation-nfc", destination: .cardAccessNumber)
    }

    internal func testScenarioActivatedNFCRoutesThroughGUI() {
      assertScenario("activated-nfc", destination: .cardAccessNumber)
    }

    internal func testScenarioRegisteredNFCRoutesThroughGUI() {
      assertScenario("registered-nfc", destination: .registeredIdentity)
    }

    internal func testRegisteredNFCCardClassifiesAndReturnsToIdentityThroughGUI() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("registered-nfc", in: app)

      let identity = app.staticTexts[UITestIdentifiers.identityStatus]
      XCTAssertTrue(identity.waitForExistence(timeout: Self.appearTimeout))
      openManagement(in: app)

      let back = app.navigationBars.buttons.firstMatch
      XCTAssertTrue(back.waitForExistence(timeout: Self.appearTimeout))
      back.tap()
      XCTAssertTrue(
        identity.waitForExistence(timeout: Self.appearTimeout),
        "dismissing PIN management lost the registered identity origin")
    }

    internal func testScenarioFactoryFreshReaderRoutesThroughGUI() {
      assertScenario("factory-fresh-reader", destination: .activation)
    }

    internal func testScenarioActivatedReaderRoutesThroughGUI() {
      assertScenario("activated-reader", destination: .readerIdentity)
    }

    internal func testScenarioPIN1RecoveryReaderRoutesThroughGUI() {
      assertScenario("pin1-recovery-reader", destination: .readerIdentity)
    }

    internal func testScenarioPIN2RecoveryReaderRoutesThroughGUI() {
      assertScenario("pin2-recovery-reader", destination: .readerIdentity)
    }

    internal func testScenarioPUKRecoveryRefusedReaderRoutesThroughGUI() {
      assertScenario("puk-recovery-refused-reader", destination: .readerIdentity)
    }

    internal func testScenarioAbsentCardRoutesThroughGUI() {
      assertScenario("absent", destination: .cardAccessNumber)
    }

    internal func testFaultPresetNoneIsConfiguredThroughGUI() {
      assertFaultPreset("none")
    }

    internal func testFaultPresetNFCDisconnectIsConfiguredThroughGUI() {
      assertFaultPreset("nfcDisconnectBeforeConnection")
    }

    internal func testFaultPresetReaderCounterFailureIsConfiguredThroughGUI() {
      assertFaultPreset("readerFailsCounterQuery")
    }

    internal func testFaultPresetCardRemovalDuringPINChangeIsConfiguredThroughGUI() {
      assertFaultPreset("cardRemovedDuringPINChange")
    }

    internal func testFaultPresetLostPIN1ActivationResponseIsConfiguredThroughGUI() {
      assertFaultPreset("responseLostAfterPIN1Activation")
    }

    internal func testFaultPresetLostPIN2ActivationResponseIsConfiguredThroughGUI() {
      assertFaultPreset("responseLostAfterPIN2Activation")
    }

    internal func testFaultPresetCertificateReadFailureIsConfiguredThroughGUI() {
      assertFaultPreset("certificateReadFailure")
    }

    internal func testFaultPresetTokenPublicationFailureIsConfiguredThroughGUI() {
      assertFaultPreset("tokenPublicationFailure")
    }

    internal func testFaultPresetCardRemovalDuringSignatureIsConfiguredThroughGUI() {
      assertFaultPreset("cardRemovedDuringSignature")
    }

    internal func testFaultPresetLostSignatureResponseIsConfiguredThroughGUI() {
      assertFaultPreset("responseLostAfterSignature")
    }

    /// The audit arrived after the oldest system this app runs on, so
    /// this check is offered only where it exists.
    internal func testVirtualCardEditorPassesAccessibilityAudit() throws {
      let app = UITestApp.launchVirtualCard()
      let overlay = app.buttons[UITestIdentifiers.virtualCardOverlay]
      XCTAssertTrue(overlay.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertEqual(overlay.label, "Virtual ID Card")
      XCTAssertFalse((overlay.value as? String ?? "").isEmpty)

      applyScenario("registered-nfc", in: app)
      openEditor(in: app)
      try app.performAccessibilityAudit { issue in
        XCTFail(
          """
          \(issue.compactDescription)
          \(issue.detailedDescription)
          Element: \(String(describing: issue.element))
          """)
        return true
      }
    }

    internal func testVirtualCardEditorIsLocalizedAndAccessibleInFinnish() {
      assertVirtualCardEditorLocalization(language: "fi")
    }

    internal func testVirtualCardEditorIsLocalizedAndAccessibleInSwedish() {
      assertVirtualCardEditorLocalization(language: "sv")
    }

    internal func testFactoryFreshNFCCardActivatesThroughGUI() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("factory-fresh-nfc", in: app)
      connect(accessNumber: "123456", pin1: "1234", in: app)

      fillSecure("managementActivationEntry", with: "1234567", in: app)
      fillSecure("managementActivationPin1", with: "4567", in: app)
      fillSecure("managementActivationPin1Repeat", with: "4567", in: app)
      fillSecure("managementActivationPin2", with: "654321", in: app)
      fillSecure("managementActivationPin2Repeat", with: "654321", in: app)
      commit(action: UITestIdentifiers.managementActivate, in: app)

      let pin1 = app.secureTextFields[UITestIdentifiers.pin1Field]
      guard pin1.waitForExistence(timeout: Self.appearTimeout) else {
        let visibleFeedback = app.staticTexts.allElementsBoundByIndex
          .map(\.label)
          .filter { !$0.isEmpty }
          .joined(separator: " | ")
        openEditor(in: app)
        let pin1Factory = app.switches["virtualCardPIN1Factory"]
        let pin2Factory = app.switches["virtualCardPIN2Factory"]
        scrollTo(pin1Factory, in: app)
        XCTAssertTrue(pin1Factory.waitForExistence(timeout: Self.appearTimeout))
        XCTAssertTrue(pin2Factory.waitForExistence(timeout: Self.appearTimeout))
        XCTFail(
          "successful activation did not reveal authentication; "
            + "feedback=\(visibleFeedback); "
            + "PIN 1 factory=\(String(describing: pin1Factory.value)), "
            + "PIN 2 factory=\(String(describing: pin2Factory.value))")
        return
      }
      XCTAssertEqual(
        pin1.value as? String,
        "Basic Code (PIN 1)",
        "PIN 1 entered before factory-card classification was retained")
    }

    internal func testCardAccessNumberAcceptsDirectGUIInput() {
      let app = UITestApp.launchVirtualCard()
      let field = app.textFields[UITestIdentifiers.cardAccessNumberField]
      XCTAssertTrue(field.waitForExistence(timeout: Self.appearTimeout))
      focusAndType(field, value: "123456", in: app)
      XCTAssertEqual(
        app.textFields[UITestIdentifiers.cardAccessNumberField].value as? String,
        "123456")
    }

    internal func testWirelessManagementRequiresLiveCardClassification() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("activated-nfc", in: app)
      let signing = app.buttons[UITestIdentifiers.signDocuments]
      let key = app.buttons[UITestIdentifiers.pinManagementButton]

      XCTAssertTrue(
        signing.waitForExistence(timeout: Self.appearTimeout),
        "wireless setup hid document signing instead of presenting it disabled")
      XCTAssertFalse(
        signing.isEnabled,
        "document signing was enabled before CAN was complete")
      XCTAssertEqual(signing.label, "Sign")
      XCTAssertTrue(app.staticTexts["Document"].exists)
      XCTAssertTrue(key.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(key.isEnabled, "PIN management was enabled before CAN was complete")

      let cache = app.buttons[UITestIdentifiers.primeStartButton]
      XCTAssertTrue(cache.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertEqual(cache.label, "Cache")
      let cardHeader = app.staticTexts["Card"]
      let documentHeader = app.staticTexts["Document"]
      XCTAssertTrue(cardHeader.exists)
      XCTAssertEqual(cardHeader.frame.minX, documentHeader.frame.minX, accuracy: 1)

      let can = app.textFields[UITestIdentifiers.cardAccessNumberField]
      let pin1 = app.secureTextFields[UITestIdentifiers.pin1Field]
      XCTAssertTrue(can.exists)
      XCTAssertTrue(pin1.exists)
      XCTAssertEqual(can.frame.height, pin1.frame.height, accuracy: 1)

      focusAndType(can, value: "123456", in: app)
      let signingEnabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"),
        object: signing)
      let keyEnabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"),
        object: key)
      XCTAssertEqual(
        XCTWaiter.wait(
          for: [signingEnabled, keyEnabled],
          timeout: Self.appearTimeout),
        .completed,
        "six-digit CAN did not enable signing and PIN management")

      openManagement(in: app)
    }

    internal func testActivatedNFCCardRevealsAuthenticationThroughGUI() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("activated-nfc", in: app)

      XCTAssertTrue(
        app.secureTextFields[UITestIdentifiers.pin1Field]
          .waitForExistence(timeout: Self.appearTimeout),
        "initial setup did not offer PIN 1 with CAN")
      connect(accessNumber: "123456", pin1: "1234", in: app)

      XCTAssertTrue(
        app.staticTexts["Identity"]
          .waitForExistence(timeout: Self.appearTimeout),
        "activated card did not continue directly through authentication")
      XCTAssertTrue(
        app.buttons[UITestIdentifiers.signDocuments]
          .waitForExistence(timeout: Self.appearTimeout),
        "validated NFC card did not reveal document signing")
    }

    internal func testWrongCardAccessNumberReturnsToSetupThroughGUI() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("activated-nfc", in: app)
      connect(accessNumber: "654321", pin1: "1234", in: app)

      let field = app.textFields[UITestIdentifiers.cardAccessNumberField]
      XCTAssertTrue(field.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertEqual(field.value as? String, "Card Access Number (CAN)")
      XCTAssertTrue(
        app.staticTexts["The Card Access Number (CAN) is incorrect."]
          .waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(app.buttons[UITestIdentifiers.managementActivate].exists)
    }

    internal func testConnectionFailureKeepsTransientCardAccessNumber() {
      let app = UITestApp.launchVirtualCard()
      openEditor(in: app)
      selectMenu(
        identifier: UITestIdentifiers.virtualCardScenario,
        option: "activated-nfc",
        in: app,
        optionIdentifier: "virtualCardScenarioOption.activated-nfc")
      selectMenu(
        identifier: UITestIdentifiers.virtualCardFault,
        option: "nfcDisconnectBeforeConnection",
        in: app,
        optionIdentifier:
          "virtualCardFaultOption.nfcDisconnectBeforeConnection",
        scrolling: true)
      applyEditor(in: app)
      connect(accessNumber: "123456", pin1: "1234", in: app)

      XCTAssertEqual(
        app.textFields[UITestIdentifiers.cardAccessNumberField].value as? String,
        "123456")
      XCTAssertTrue(
        app.staticTexts["The identity card could not be read. Try again."]
          .waitForExistence(timeout: Self.appearTimeout))
    }

    internal func testPartialActivationRequestsOnlyPIN2ThroughGUI() {
      let app = UITestApp.launchVirtualCard()
      applyScenario("partial-activation-nfc", in: app)

      connect(accessNumber: "123456", pin1: "1234", in: app)

      XCTAssertTrue(
        app.secureTextFields["managementActivationPin2"]
          .waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(app.secureTextFields["managementActivationPin1"].exists)
    }

    internal func testChangePIN1RunsThroughGUI() {
      assertCredentialJourney(
        CredentialJourney(
          task: "Change PIN 1",
          fields: [
            ("managementChangePIN1Current", "1234"),
            ("managementChangePIN1New", "9876"),
            ("managementChangePIN1Repeat", "9876"),
          ],
          action: UITestIdentifiers.managementChangePin1,
          outcome: "PIN 1 changed"))
    }

    internal func testChangePIN2RunsThroughGUI() {
      assertCredentialJourney(
        CredentialJourney(
          task: "Change PIN 2",
          fields: [
            ("managementChangePIN2Current", "123456"),
            ("managementChangePIN2New", "987654"),
            ("managementChangePIN2Repeat", "987654"),
          ],
          action: UITestIdentifiers.managementChangePin2,
          outcome: "PIN 2 changed"))
    }

    internal func testResetPIN1RunsThroughGUI() {
      assertCredentialJourney(
        CredentialJourney(
          task: "Reset PIN 1",
          fields: [
            ("managementResetPIN1Puk", "12345678"),
            ("managementResetPIN1New", "9876"),
            ("managementResetPIN1Repeat", "9876"),
          ],
          action: UITestIdentifiers.managementResetPin1,
          outcome: "PIN 1 reset"))
    }

    internal func testResetPIN2RunsThroughGUI() {
      assertCredentialJourney(
        CredentialJourney(
          task: "Reset PIN 2",
          fields: [
            ("managementResetPIN2Puk", "12345678"),
            ("managementResetPIN2New", "987654"),
            ("managementResetPIN2Repeat", "987654"),
          ],
          action: UITestIdentifiers.managementResetPin2,
          outcome: "PIN 2 reset"))
    }

    internal func testRetryCounterEditedInGUISelectsRecovery() {
      let app = UITestApp.launchVirtualCard()
      openEditor(in: app)
      selectMenu(
        identifier: UITestIdentifiers.virtualCardScenario,
        option: "activated-reader",
        in: app,
        optionIdentifier: "virtualCardScenarioOption.activated-reader")
      let stepper = app.steppers[UITestIdentifiers.virtualCardPIN1Attempts]
      scrollTo(stepper, in: app)
      XCTAssertTrue(stepper.waitForExistence(timeout: Self.appearTimeout))
      let decrement = stepper.buttons.firstMatch
      XCTAssertTrue(decrement.exists)
      decrement.tap()
      decrement.tap()
      decrement.tap()
      applyEditor(in: app)

      openManagement(in: app)

      XCTAssertTrue(
        app.buttons["Reset PIN 1"].firstMatch
          .waitForExistence(timeout: Self.appearTimeout),
        "a PIN 1 retry floor did not select PIN 1 recovery")
    }

    internal func testQualifiedDocumentSigningSucceedsThroughGUI() {
      let app = signingApp()

      fillSecure(UITestIdentifiers.signingPIN2, with: "123456", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()

      XCTAssertTrue(
        app.buttons[UITestIdentifiers.signDocuments]
          .waitForExistence(timeout: Self.appearTimeout),
        "successful signing did not return to the front page")
      XCTAssertFalse(
        app.buttons[UITestIdentifiers.signingCommit].exists,
        "the signing screen remained after success")
    }

    internal func testWrongSignaturePINConsumesOneAttemptThroughGUI() {
      let app = signingApp()

      fillSecure(UITestIdentifiers.signingPIN2, with: "000000", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()
      assertSigningMessage(contains: "PIN 2 is incorrect", in: app)
      assertPIN2Attempts(4, in: app)
    }

    internal func testSignatureRetryFloorIsEnforcedThroughGUI() {
      let app = signingApp(pin2Attempts: 2)

      fillSecure(UITestIdentifiers.signingPIN2, with: "123456", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()
      assertSigningMessage(contains: "Operation refused", in: app)
      assertPIN2Attempts(2, in: app)
    }

    internal func testMissingSignatureCertificateFailsThroughGUI() {
      let app = signingApp(signatureCertificate: "missing")

      fillSecure(UITestIdentifiers.signingPIN2, with: "123456", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()
      assertSigningMessage(contains: "certificate is unavailable", in: app)
      assertPIN2Attempts(5, in: app)
    }

    internal func testCardRemovalBeforeSignatureDoesNotSpendAttempt() {
      let app = signingApp(fault: "cardRemovedDuringSignature")

      fillSecure(UITestIdentifiers.signingPIN2, with: "123456", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()
      assertSigningMessage(contains: "connection was lost", in: app)
      assertPIN2Attempts(5, in: app)
    }

    internal func testLostResponseAfterSignaturePreservesCardExecution() {
      let app = signingApp(
        pin2Attempts: 4,
        fault: "responseLostAfterSignature")

      fillSecure(UITestIdentifiers.signingPIN2, with: "123456", in: app)
      app.buttons[UITestIdentifiers.signingCommit].tap()
      assertSigningMessage(contains: "connection was lost", in: app)
      assertPIN2Attempts(5, in: app)
    }

    internal func testSigningScreenIsLocalizedInFinnish() {
      assertSigningLocalization(
        language: "fi",
        labels: ["Allekirjoitustapa", "Yksittäin (PDF)", "Pakettina (ASiC-E)"])
    }

    internal func testSigningScreenIsLocalizedInSwedish() {
      assertSigningLocalization(
        language: "sv",
        labels: ["Signeringssätt", "Separat (PDF)", "Som paket (ASiC-E)"])
    }

    private func assertScenario(
      _ scenario: String,
      destination: Destination
    ) {
      let app = UITestApp.launchVirtualCard()
      applyScenario(scenario, in: app)
      assertDestination(destination, scenario: scenario, in: app)
    }

    private func assertFaultPreset(_ preset: String) {
      let app = UITestApp.launchVirtualCard()
      openEditor(in: app)
      selectMenu(
        identifier: UITestIdentifiers.virtualCardFault,
        option: preset,
        in: app,
        optionIdentifier: "virtualCardFaultOption.\(preset)",
        scrolling: true)
      applyEditor(in: app)
    }

    private func assertCredentialJourney(_ journey: CredentialJourney) {
      let app = UITestApp.launchVirtualCard()
      applyScenario("activated-reader", in: app)
      openManagement(in: app)
      selectMenu(
        identifier: UITestIdentifiers.managementTask,
        option: journey.task,
        in: app)
      for field in journey.fields {
        fillSecure(field.identifier, with: field.value, in: app)
      }
      commit(action: journey.action, in: app)
      XCTAssertTrue(
        app.staticTexts[journey.outcome]
          .waitForExistence(timeout: Self.appearTimeout),
        "\(journey.task) did not publish its outcome")
    }

    private func assertVirtualCardEditorLocalization(language: String) {
      let app = UITestApp.launch(
        language: language,
        arguments: ["--virtual-card", "absent"])
      let overlay = app.buttons[UITestIdentifiers.virtualCardOverlay]
      XCTAssertTrue(
        overlay.waitForExistence(timeout: Self.appearTimeout),
        "floating Virtual ID Card is missing in \(language)")
      XCTAssertFalse(overlay.label.isEmpty)
      XCTAssertNotEqual(
        overlay.label,
        "Virtual ID Card",
        "Virtual ID Card kept its English accessibility label in \(language)")

      openEditor(in: app)
      let scenario = app.descendants(matching: .any)[
        UITestIdentifiers.virtualCardScenario
      ]
      let fault = app.descendants(matching: .any)[
        UITestIdentifiers.virtualCardFault
      ]
      XCTAssertTrue(scenario.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(scenario.label.isEmpty)
      XCTAssertFalse(
        scenario.label.localizedCaseInsensitiveContains("Preset"),
        "scenario picker kept its English label in \(language)")

      scrollTo(fault, in: app)
      XCTAssertTrue(fault.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(fault.label.isEmpty)
      XCTAssertFalse(
        fault.label.localizedCaseInsensitiveContains("Fault"),
        "fault picker kept its English label in \(language)")
    }

    private func assertSigningLocalization(
      language: String,
      labels: [String]
    ) {
      let app = UITestApp.launch(
        language: language,
        arguments: ["--virtual-card", "absent"])
      configureSigningCard(in: app)
      openSigning(in: app)

      let commit = app.buttons[UITestIdentifiers.signingCommit]
      XCTAssertTrue(commit.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertFalse(commit.label.isEmpty)
      XCTAssertNotEqual(
        commit.label,
        "Sign documents",
        "signing action remained English in \(language)")
      for label in labels {
        XCTAssertTrue(
          app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch.waitForExistence(timeout: Self.appearTimeout),
          "missing \(language) signing label: \(label)")
      }
    }

    private func assertDestination(
      _ destination: Destination,
      scenario: String,
      in app: XCUIApplication
    ) {
      let element: XCUIElement
      switch destination {
      case .cardAccessNumber:
        element = app.textFields[UITestIdentifiers.cardAccessNumberField]

      case .activation:
        element = app.buttons[UITestIdentifiers.managementActivate]

      case .readerIdentity:
        element = app.staticTexts[UITestIdentifiers.readerCardHolder]

      case .registeredIdentity:
        element = app.staticTexts[UITestIdentifiers.identityStatus]
      }
      XCTAssertTrue(
        element.waitForExistence(timeout: Self.appearTimeout),
        "\(scenario) reached the wrong UI destination")
    }

    private func applyScenario(
      _ scenario: String,
      in app: XCUIApplication
    ) {
      openEditor(in: app)
      selectMenu(
        identifier: UITestIdentifiers.virtualCardScenario,
        option: scenario,
        in: app,
        optionIdentifier: "virtualCardScenarioOption.\(scenario)")
      applyEditor(in: app)
    }

    private func signingApp(
      pin2Attempts: Int = 5,
      signatureCertificate: String? = nil,
      fault: String? = nil
    ) -> XCUIApplication {
      let app = UITestApp.launchVirtualCard()
      configureSigningCard(
        pin2Attempts: pin2Attempts,
        signatureCertificate: signatureCertificate,
        fault: fault,
        in: app)
      openSigning(in: app)
      return app
    }

    private func configureSigningCard(
      pin2Attempts: Int = 5,
      signatureCertificate: String? = nil,
      fault: String? = nil,
      in app: XCUIApplication
    ) {
      openEditor(in: app)
      selectMenu(
        identifier: UITestIdentifiers.virtualCardScenario,
        option: "activated-reader",
        in: app,
        optionIdentifier: "virtualCardScenarioOption.activated-reader")

      if pin2Attempts != 5 {
        let stepper = app.steppers[UITestIdentifiers.virtualCardPIN2Attempts]
        scrollTo(stepper, in: app)
        XCTAssertTrue(stepper.waitForExistence(timeout: Self.appearTimeout))
        for _ in pin2Attempts..<5 { stepper.buttons.firstMatch.tap() }
      }

      if let signatureCertificate {
        selectMenu(
          identifier: "virtualCardSignatureCertificate",
          option: signatureCertificate,
          in: app,
          optionIdentifier:
            "virtualCardCertificateOption.\(signatureCertificate)",
          scrolling: true)
      }

      let pending = app.buttons["virtualCardSigningPending"]
      scrollTo(pending, in: app)
      XCTAssertTrue(pending.waitForExistence(timeout: Self.appearTimeout))
      pending.tap()

      if let fault {
        selectMenu(
          identifier: UITestIdentifiers.virtualCardFault,
          option: fault,
          in: app,
          optionIdentifier: "virtualCardFaultOption.\(fault)",
          scrolling: true)
      }
      applyEditor(in: app)
    }

    private func openSigning(in app: XCUIApplication) {
      let link = app.buttons[UITestIdentifiers.signDocuments]
      XCTAssertTrue(link.waitForExistence(timeout: Self.appearTimeout))
      link.tap()
      XCTAssertTrue(
        app.secureTextFields[UITestIdentifiers.signingPIN2]
          .waitForExistence(timeout: Self.appearTimeout),
        "pending virtual document was not prepared")
    }

    private func assertSigningMessage(
      contains expected: String,
      in app: XCUIApplication
    ) {
      let message = app.descendants(matching: .any)[
        UITestIdentifiers.signingMessage
      ]
      XCTAssertTrue(message.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertTrue(
        message.label.localizedCaseInsensitiveContains(expected),
        "unexpected signing feedback: \(message.label)")
    }

    private func assertPIN2Attempts(
      _ expected: Int,
      in app: XCUIApplication
    ) {
      openEditor(in: app)
      let stepper = app.steppers[UITestIdentifiers.virtualCardPIN2Attempts]
      scrollTo(stepper, in: app)
      XCTAssertTrue(stepper.waitForExistence(timeout: Self.appearTimeout))
      XCTAssertTrue(
        (stepper.value as? String ?? "").contains("\(expected)"),
        "PIN 2 counter is \(stepper.value ?? "missing"), expected \(expected)")
      app.buttons[UITestIdentifiers.virtualCardApply].tap()
    }

    private func openEditor(in app: XCUIApplication) {
      let overlay = app.buttons[UITestIdentifiers.virtualCardOverlay]
      XCTAssertTrue(
        overlay.waitForExistence(timeout: Self.appearTimeout),
        "floating Virtual ID Card is missing")
      overlay.tap()
      XCTAssertTrue(
        app.descendants(matching: .any)[UITestIdentifiers.virtualCardEditor]
          .waitForExistence(timeout: Self.appearTimeout),
        "Virtual ID Card editor did not open")
    }

    private func applyEditor(in app: XCUIApplication) {
      let apply = app.buttons[UITestIdentifiers.virtualCardApply]
      XCTAssertTrue(apply.waitForExistence(timeout: Self.appearTimeout))
      apply.tap()
      let editor = app.descendants(matching: .any)[
        UITestIdentifiers.virtualCardEditor
      ]
      let editorDismissed = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == false"),
        object: editor)
      XCTAssertEqual(
        XCTWaiter.wait(for: [editorDismissed], timeout: Self.appearTimeout),
        .completed,
        "Virtual ID Card editor did not close")
      let overlay = app.buttons[UITestIdentifiers.virtualCardOverlay]
      let overlayReady = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == true AND hittable == true"),
        object: overlay)
      XCTAssertEqual(
        XCTWaiter.wait(for: [overlayReady], timeout: Self.appearTimeout),
        .completed,
        "floating Virtual ID Card did not become ready")
    }

    private func selectMenu(
      identifier: String,
      option: String,
      in app: XCUIApplication,
      optionIdentifier: String? = nil,
      scrolling: Bool = false
    ) {
      // A menu surfaces as its own control and again as its label; either opens it.
      let menu = app.descendants(matching: .any)[identifier].firstMatch
      if scrolling {
        scrollTo(menu, in: app)
      }
      XCTAssertTrue(
        menu.waitForExistence(timeout: Self.appearTimeout),
        "\(identifier) menu is missing")
      menu.tap()
      let choice =
        optionIdentifier.map {
          app.descendants(matching: .any)[$0].firstMatch
        } ?? app.buttons[option].firstMatch
      XCTAssertTrue(
        choice.waitForExistence(timeout: Self.appearTimeout),
        "\(option) menu choice is missing")
      choice.tap()
    }

    private func connect(
      accessNumber: String,
      pin1: String,
      in app: XCUIApplication
    ) {
      let field = app.textFields[UITestIdentifiers.cardAccessNumberField]
      XCTAssertTrue(field.waitForExistence(timeout: Self.appearTimeout))
      focusAndType(field, value: accessNumber, in: app)
      let pin1Field = app.secureTextFields[UITestIdentifiers.pin1Field]
      XCTAssertTrue(pin1Field.waitForExistence(timeout: Self.appearTimeout))
      focusAndType(pin1Field, value: pin1, in: app)
      let cache = app.buttons[UITestIdentifiers.primeStartButton]
      let enabled = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "enabled == true"),
        object: cache)
      XCTAssertEqual(
        XCTWaiter.wait(for: [enabled], timeout: Self.appearTimeout),
        .completed,
        "Cache is disabled for complete CAN and PIN 1 entries")
      cache.tap()
    }

    private func openManagement(in app: XCUIApplication) {
      let key = app.buttons[UITestIdentifiers.pinManagementButton]
      XCTAssertTrue(key.waitForExistence(timeout: Self.appearTimeout))
      key.tap()
      XCTAssertTrue(
        app.descendants(matching: .any)[UITestIdentifiers.managementTask]
          .waitForExistence(timeout: Self.appearTimeout))
    }

    private func fillSecure(
      _ identifier: String,
      with value: String,
      in app: XCUIApplication
    ) {
      let field = app.secureTextFields[identifier]
      XCTAssertTrue(
        field.waitForExistence(timeout: Self.appearTimeout),
        "\(identifier) field is missing")
      focusAndType(field, value: value, in: app)
    }

    private func focusAndType(
      _ field: XCUIElement,
      value: String,
      in app: XCUIApplication
    ) {
      let ready = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == true AND hittable == true"),
        object: field)
      XCTAssertEqual(
        XCTWaiter.wait(for: [ready], timeout: Self.appearTimeout),
        .completed,
        "\(field.identifier) did not become ready for input")
      app.activate()
      field.tap()
      let keyboard = app.keyboards.firstMatch
      XCTAssertTrue(
        keyboard.waitForExistence(timeout: Self.appearTimeout),
        "The numeric keyboard did not appear for \(field.identifier)")
      let focused = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "hasKeyboardFocus == true"),
        object: field)
      XCTAssertEqual(
        XCTWaiter.wait(for: [focused], timeout: Self.appearTimeout),
        .completed,
        "\(field.identifier) did not receive keyboard focus")
      field.typeText(value)
    }

    private func commit(action identifier: String, in app: XCUIApplication) {
      let action = app.buttons[identifier]
      scrollTo(action, in: app)
      XCTAssertTrue(action.isEnabled, "\(identifier) is disabled")
      action.tap()
      // iOS exposes nested outer and inner button nodes for each centered
      // alert action. Optimized element queries miss these nodes on iOS 26,
      // while a full accessibility snapshot materializes both identifiers.
      // Tapping waits for application quiescence, so this is an event barrier,
      // not a timing delay.
      let hierarchy = app.debugDescription
      let snapshot = XCTAttachment(string: hierarchy)
      snapshot.name = "Confirmation accessibility snapshot"
      snapshot.lifetime = .deleteOnSuccess
      add(snapshot)
      guard
        let center = accessibilityFrameCenter(
          of: UITestIdentifiers.managementConfirm,
          in: hierarchy
        )
      else {
        XCTFail("\(identifier) did not present its confirmation")
        return
      }
      let semanticConfirm = app.descendants(matching: .any)
        .matching(identifier: UITestIdentifiers.managementConfirm)
        .firstMatch
      if semanticConfirm.exists {
        semanticConfirm.tap()
        return
      }
      app.coordinate(withNormalizedOffset: .zero)
        .withOffset(center)
        .tap()
    }

    private func accessibilityFrameCenter(of identifier: String, in hierarchy: String) -> CGVector?
    {
      let number = #"-?[0-9]+(?:\.[0-9]+)?"#
      let escapedIdentifier = NSRegularExpression.escapedPattern(for: identifier)
      let pattern =
        #"\{\{("# + number + #"), ("# + number + #")\}, \{("#
        + number + #"), ("# + number + #")\}\}, identifier: '"#
        + escapedIdentifier + #"'"#
      guard
        let expression = try? NSRegularExpression(pattern: pattern),
        let match = expression.firstMatch(
          in: hierarchy,
          range: NSRange(hierarchy.startIndex..., in: hierarchy)
        )
      else {
        return nil
      }

      func value(at index: Int) -> CGFloat? {
        guard let range = Range(match.range(at: index), in: hierarchy) else { return nil }
        guard let parsed = Double(String(hierarchy[range])) else { return nil }
        return CGFloat(parsed)
      }

      guard
        let originX = value(at: 1),
        let originY = value(at: 2),
        let width = value(at: 3),
        let height = value(at: 4)
      else {
        return nil
      }
      return CGVector(dx: originX + width / 2, dy: originY + height / 2)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
      for _ in 0..<8 where !element.isHittable {
        app.swipeUp()
      }
    }
  }

#endif
