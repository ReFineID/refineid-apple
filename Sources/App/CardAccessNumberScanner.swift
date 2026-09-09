// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  @preconcurrency import AVFoundation
  import SwiftUI

  /// Reads the structured CAN QR code printed on the card.
  ///
  /// The scanner owns its AVFoundation session. That matters because the
  /// torch and the video stream must be configured by the same owner:
  /// changing a camera underneath VisionKit's scanner freezes its preview.
  internal struct CardAccessNumberScanner: UIViewControllerRepresentable {
    /// Whether this device has a usable back camera.
    internal static var isAvailable: Bool {
      guard CardAccessNumberCapturePipeline.preferredBackCamera != nil else {
        return false
      }
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized, .notDetermined:
        return true

      case .denied, .restricted:
        return false

      @unknown default:
        return false
      }
    }

    /// Whether the back camera can illuminate the card.
    internal static var hasTorch: Bool {
      CardAccessNumberCapturePipeline.preferredBackCamera?.hasTorch == true
    }

    /// SwiftUI's desired light state.
    @Binding internal var torchEnabled: Bool

    /// Called with the CAN parsed from a supported QR payload.
    internal let onRecognize: @MainActor @Sendable (String) -> Void

    /// Ends all camera work when SwiftUI removes the controller.
    internal static func dismantleUIViewController(
      _ scanner: CardAccessNumberScannerViewController,
      coordinator _: Void
    ) {
      scanner.stop()
    }

    internal func makeUIViewController(
      context _: Context
    ) -> CardAccessNumberScannerViewController {
      CardAccessNumberScannerViewController(onRecognize: onRecognize)
    }

    internal func updateUIViewController(
      _ scanner: CardAccessNumberScannerViewController,
      context _: Context
    ) {
      scanner.setTorchEnabled(torchEnabled)
    }
  }

#endif
