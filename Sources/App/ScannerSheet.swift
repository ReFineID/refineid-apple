// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  import SwiftUI

  /// The camera, framed so it can be dismissed, with its light control.
  internal struct ScannerSheet: View {
    @Binding internal var torchEnabled: Bool
    @Binding internal var isScanning: Bool

    /// Receives the scanned digits before the sheet dismisses itself.
    internal let complete: (String) -> Void

    internal var body: some View {
      NavigationStack {
        CardAccessNumberScanner(
          torchEnabled: $torchEnabled
        ) { digits in
          torchEnabled = false
          complete(digits)
          isScanning = false
        }
        .ignoresSafeArea()
        .navigationTitle("Scan card QR code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
      }
      .onDisappear {
        torchEnabled = false
      }
    }

    /// Dismissal and light controls kept above the live preview.
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
      ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
          torchEnabled = false
          isScanning = false
        }
      }
      if CardAccessNumberScanner.hasTorch {
        ToolbarItem(placement: .primaryAction) {
          Button {
            torchEnabled.toggle()
          } label: {
            Label(
              torchEnabled ? "Turn light off" : "Turn light on",
              systemImage: torchEnabled
                ? "flashlight.on.fill" : "flashlight.off.fill")
          }
          .accessibilityIdentifier("cardAccessNumberScannerTorch")
        }
      }
    }
  }

#endif
