// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  @preconcurrency import AVFoundation
  import UIKit

  /// Presents the live preview and controls the owned capture pipeline.
  @MainActor
  internal final class CardAccessNumberScannerViewController:
    UIViewController
  {
    private let pipeline = CardAccessNumberCapturePipeline()
    private let recognitionQueue = DispatchQueue(
      label: "fi.refineid.card-access-number-recognition",
      qos: .userInitiated)
    private let recognizer: CardAccessNumberQRRecognizer
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(
      session: pipeline.session)
    private var didRequestStart = false

    /// Creates a scanner that reports one access number.
    internal init(
      onRecognize: @escaping @MainActor @Sendable (String) -> Void
    ) {
      recognizer = CardAccessNumberQRRecognizer(
        onRecognize: onRecognize)
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    internal required init?(coder _: NSCoder) {
      nil
    }

    override internal func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .black
      previewLayer.videoGravity = .resizeAspectFill
      view.layer.addSublayer(previewLayer)
      view.addGestureRecognizer(
        UITapGestureRecognizer(
          target: self,
          action: #selector(focusOnTap(_:))))
    }

    override internal func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      previewLayer.frame = view.bounds
    }

    override internal func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      guard !didRequestStart else { return }
      didRequestStart = true

      Task { @MainActor [weak self] in
        await self?.startWhenAuthorized()
      }
    }

    override internal func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      pipeline.stop()
    }

    /// Requests camera access when needed, then starts the one pipeline.
    private func startWhenAuthorized() async {
      let isAuthorized: Bool
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized:
        isAuthorized = true

      case .notDetermined:
        isAuthorized = await AVCaptureDevice.requestAccess(for: .video)

      case .denied, .restricted:
        isAuthorized = false

      @unknown default:
        isAuthorized = false
      }
      guard isAuthorized else { return }
      guard
        pipeline.configure(
          recognizer: recognizer,
          recognitionQueue: recognitionQueue)
      else {
        return
      }
      if let connection = previewLayer.connection {
        CardAccessNumberCapturePipeline.orientPortrait(connection)
      }
      pipeline.start()
    }

    /// Lets the user recover focus by tapping the small QR code.
    @objc
    private func focusOnTap(_ recognizer: UITapGestureRecognizer) {
      let layerPoint = recognizer.location(in: view)
      let devicePoint = previewLayer.captureDevicePointConverted(
        fromLayerPoint: layerPoint)
      pipeline.focus(at: devicePoint)
    }

    /// Changes the lamp without touching a foreign capture session.
    internal func setTorchEnabled(_ enabled: Bool) {
      pipeline.setTorchEnabled(enabled)
    }

    /// Ends all camera work when SwiftUI removes the controller.
    internal func stop() {
      pipeline.stop()
    }
  }

#endif
