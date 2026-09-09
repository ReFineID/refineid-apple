// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD

  import XCTest

  /// The remote pairing disconnect flow.
  ///
  /// After the holder removes the pairing the phone must reset its own
  /// UI to the Connect state and notify the remote side so its UI follows.
  @MainActor
  internal final class RemotePairingUITests: XCTestCase {
    /// Long enough for a first launch on the oldest supported hardware.
    private static let appearTimeout: TimeInterval = 15

    override internal func setUp() {
      super.setUp()
      continueAfterFailure = false
    }

    override internal func tearDown() {
      continueAfterFailure = true
      super.tearDown()
    }

    /// Tapping Connect opens inline pairing controls.
    internal func testConnectOpensInlinePairingControls() {
      let app = UITestApp.launch()
      let connect = element(UITestIdentifiers.remoteCard, in: app)
      XCTAssertTrue(
        connect.waitForExistence(timeout: Self.appearTimeout),
        "the remote card row did not appear")
    }

    /// Removing the pairing resets the row to its initial state.
    internal func testDisconnectResetsRowToConnectState() {
      let app = UITestApp.launch(arguments: ["--pretend-paired"])
      let disconnect = app.descendants(matching: .any)["remoteDisconnectButton"]
        .firstMatch
      guard disconnect.waitForExistence(timeout: Self.appearTimeout) else {
        XCTFail("Remove-pairing control did not appear for a pretend-paired launch")
        return
      }
      disconnect.tap()

      let connect = app.descendants(matching: .any)["remoteConnectButton"]
        .firstMatch
      XCTAssertTrue(
        connect.waitForExistence(timeout: Self.appearTimeout),
        "Connect button did not reappear after Disconnect")
    }

    /// Finds a control by identifier whatever element type it took.
    private func element(
      _ identifier: String,
      in app: XCUIApplication
    ) -> XCUIElement {
      app.descendants(matching: .any)[identifier].firstMatch
    }
  }

#endif
