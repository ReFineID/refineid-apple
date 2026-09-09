// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI
  import UIKit

  /// Floating access to the editable card while a demonstration is active.
  internal struct VirtualIDCardOverlay: View {
    // MARK: Static Properties

    private enum Constants {
      static let bottomPadding: CGFloat = 64
      static let red = 0.65
      static let green = 0.0
      static let blue = 0.0
      static let trailingPadding: CGFloat = 12
    }

    /// White text on the system red fill does not meet normal-text contrast.
    ///
    /// Keep the diagnostic meaning red while meeting the accessibility audit.
    private static let accessibleRed = Color(
      red: Constants.red,
      green: Constants.green,
      blue: Constants.blue
    )

    // MARK: SwiftUI Properties

    @ObservedObject private var demoMode = DemoMode.shared

    // MARK: Properties

    internal let openEditor: () -> Void

    // MARK: Computed Properties

    private var statusDescription: String {
      let card = demoMode.state.card
      switch (card.transport, card.cardPresent) {
      case (.nearField, true):
        return virtualCardLocalized(
          "status.nfcCardPresent",
          defaultValue: "NFC, card present")

      case (.nearField, false):
        return virtualCardLocalized(
          "status.nfcNoCard",
          defaultValue: "NFC, no card present")

      case (.reader, true):
        return virtualCardLocalized(
          "status.readerCardPresent",
          defaultValue: "Card reader, card present")

      case (.reader, false):
        return virtualCardLocalized(
          "status.readerNoCard",
          defaultValue: "Card reader, no card present")
      }
    }

    // MARK: Content Properties

    internal var body: some View {
      Button {
        // The CAN field is intentionally focused when it is the only setup
        // input. End that responder session before presenting the editor;
        // otherwise UIKit can restore a detached text input when the sheet
        // closes, making the visible field ignore both touch and VoiceOver.
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder),
          to: nil,
          from: nil,
          for: nil)
        openEditor()
      } label: {
        Label(
          virtualCardLocalized("title", defaultValue: "Virtual ID Card"),
          systemImage: "creditcard")
      }
      .buttonStyle(.borderedProminent)
      .tint(Self.accessibleRed)
      .accessibilityIdentifier("virtualCardOverlay")
      .accessibilityLabel(
        Text(virtualCardLocalized("title", defaultValue: "Virtual ID Card"))
      )
      .accessibilityValue(Text(statusDescription))
      .accessibilityHint(
        Text(
          virtualCardLocalized(
            "openHint",
            defaultValue: "Opens the virtual card settings."))
      )
      .padding(.trailing, Constants.trailingPadding)
      .padding(.bottom, Constants.bottomPadding)
    }
  }

#endif
