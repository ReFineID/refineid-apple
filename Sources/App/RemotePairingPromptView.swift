// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import SwiftUI

  internal struct RemotePairingPromptView: View {
    private enum Layout {
      static let retryDelayNanoseconds: UInt64 = 1_000_000_000
      /// The invitation wraps past this width instead of stretching
      /// the content-sized window to fit one long line.
      static let promptMaxWidth: CGFloat = 600
      static let demoCardTopPadding: CGFloat = 4
    }

    @StateObject private var model = RappPairingModel()

    @ObservedObject private var cardPresence = CardPresence.shared

    internal var body: some View {
      Section {
        promptText
          .frame(maxWidth: Layout.promptMaxWidth, alignment: .leading)
        Button {
          DemoMode.shared.activate(scenario: DemoMode.defaultScenario)
          DemoMode.shared.setEditorPresented(true)
        } label: {
          Label(
            String(localized: "Explore with a Virtual Demo Card"),
            systemImage: "creditcard"
          )
        }
        .buttonStyle(.link)
        .padding(.top, Layout.demoCardTopPadding)
        .accessibilityIdentifier("exploreVirtualDemoCardButton")
      }
      .onAppear {
        ensureOffer()
      }
      .onReceive(model.$phase) { phase in
        switch phase {
        case .failed:
          Task { @MainActor in
            try? await Task.sleep(nanoseconds: Layout.retryDelayNanoseconds)
            ensureOffer()
          }

        default:
          break
        }
      }
    }

    @ViewBuilder private var promptText: some View {
      if case .offer(let code) = model.phase {
        let formattedCode = RappPairingCode.formatted(code)
        if cardPresence.isReaderConnected {
          Text(
            String(
              localized: """
                Insert your identity card into the reader, open RefineID on iPhone, \
                or connect an Android phone with code: \(formattedCode)
                """
            )
          )
          .textSelection(.enabled)
          .accessibilityIdentifier("pairingPrompt")
        } else {
          Text(
            String(
              localized: """
                Connect a card reader, open RefineID on iPhone, \
                or connect an Android phone with code: \(formattedCode)
                """
            )
          )
          .textSelection(.enabled)
          .accessibilityIdentifier("pairingPrompt")
        }
      } else if case .connecting = model.phase {
        Text(String(localized: "Connecting..."))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("pairingPrompt")
      } else {
        Text(String(localized: "Preparing pairing code..."))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("pairingPrompt")
      }
    }

    private func ensureOffer() {
      switch model.phase {
      case .offer, .connecting:
        break

      default:
        model.createOffer()
      }
    }
  }

#endif
