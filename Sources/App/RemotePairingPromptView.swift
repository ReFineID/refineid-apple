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
      static let bulletSpacing: CGFloat = 6
      static let bulletItemSpacing: CGFloat = 6
    }

    @StateObject private var model = RappPairingModel()

    @ObservedObject private var cardPresence = CardPresence.shared

    internal var body: some View {
      Section {
        promptText
          .frame(maxWidth: Layout.promptMaxWidth, alignment: .leading)
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
        VStack(alignment: .leading, spacing: Layout.bulletItemSpacing) {
          bulletItem(
            String(
              localized: "Open RefineID on phone (connect with \(formattedCode) if code is needed)"
            )
          )
          if cardPresence.isReaderConnected {
            bulletItem(
              String(
                localized: "Insert card to reader"
              )
            )
          }
        }
        .textSelection(.enabled)
        .accessibilityIdentifier("pairingPrompt")
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

    private func bulletItem(_ text: String) -> some View {
      HStack(alignment: .firstTextBaseline, spacing: Layout.bulletSpacing) {
        Text("•")
          .accessibilityHidden(true)
        Text(text)
      }
      .accessibilityElement(children: .combine)
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
