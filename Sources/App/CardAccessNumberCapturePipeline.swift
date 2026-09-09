// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  @preconcurrency import AVFoundation

  /// Owns the camera objects and serializes start, stop, and torch work.
  internal final class CardAccessNumberCapturePipeline: @unchecked Sendable {
    /// Portrait rotation applied before the first camera frame.
    internal static let portraitRotationAngle: CGFloat = 90

    // Normalized camera coordinates are necessarily numeric fractions.
    // swiftlint:disable no_magic_numbers

    /// Center of the card-scanning region in device coordinates.
    private static let scanCenter = CGPoint(x: 0.5, y: 0.5)

    /// Large central region in which the user is expected to place the QR.
    private static let scanFocusRect = CGRect(
      x: 0.2,
      y: 0.2,
      width: 0.6,
      height: 0.6)

    // swiftlint:enable no_magic_numbers

    /// Best rear camera for reading a small QR code at close range.
    ///
    /// Prefer a virtual multi-camera device so iPhone can preserve the
    /// wide-angle field of view while falling back to its closer-focusing
    /// ultra-wide constituent when the card is near the lens.
    internal static var preferredBackCamera: AVCaptureDevice? {
      let preferredTypes: [AVCaptureDevice.DeviceType] = [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera,
        .builtInWideAngleCamera,
      ]
      for deviceType in preferredTypes {
        if let device = AVCaptureDevice.default(
          deviceType,
          for: .video,
          position: .back)
        {
          return device
        }
      }
      return nil
    }

    /// Session shared with the preview layer.
    internal let session = AVCaptureSession()

    private let queue = DispatchQueue(
      label: "fi.refineid.card-access-number-camera",
      qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var camera: AVCaptureDevice?
    private var isConfigured = false

    /// Points the connection at portrait before the first frame arrives.
    ///
    /// The rotation angle replaced the orientation enumeration in iOS 17,
    /// and 90 degrees is the angle that enumeration called portrait.
    internal static func orientPortrait(_ connection: AVCaptureConnection) {
      guard connection.isVideoRotationAngleSupported(portraitRotationAngle)
      else { return }
      connection.videoRotationAngle = portraitRotationAngle
    }

    /// Configures the one capture session used by preview, QR, and torch.
    @MainActor
    internal func configure(
      recognizer: CardAccessNumberQRRecognizer,
      recognitionQueue: DispatchQueue
    ) -> Bool {
      guard !isConfigured else { return camera != nil }
      guard
        let selectedCamera = Self.preferredBackCamera,
        let input = try? AVCaptureDeviceInput(device: selectedCamera)
      else {
        return false
      }

      session.beginConfiguration()
      defer { session.commitConfiguration() }
      if session.canSetSessionPreset(.hd4K3840x2160) {
        session.sessionPreset = .hd4K3840x2160
      } else {
        session.sessionPreset = .high
      }

      guard session.canAddInput(input), session.canAddOutput(output) else {
        return false
      }
      session.addInput(input)

      output.alwaysDiscardsLateVideoFrames = true
      output.setSampleBufferDelegate(
        recognizer,
        queue: recognitionQueue)
      session.addOutput(output)

      if let connection = output.connection(with: .video) {
        Self.orientPortrait(connection)
      }

      configureCloseFocus(on: selectedCamera)
      camera = selectedCamera
      isConfigured = true
      return true
    }

    /// Configures fast near focus without preventing virtual-camera fallback.
    private func configureCloseFocus(on camera: AVCaptureDevice) {
      do {
        try camera.lockForConfiguration()
        defer { camera.unlockForConfiguration() }

        if camera.primaryConstituentDeviceSwitchingBehavior
          != .unsupported
        {
          camera.setPrimaryConstituentDeviceSwitchingBehavior(
            .auto,
            restrictedSwitchingBehaviorConditions: [])
        }
        camera.videoZoomFactor = wideAngleZoomFactor(for: camera)

        if camera.isFocusRectOfInterestSupported {
          camera.focusRectOfInterest = Self.scanFocusRect
        } else if camera.isFocusPointOfInterestSupported {
          camera.focusPointOfInterest = Self.scanCenter
        }
        if camera.isAutoFocusRangeRestrictionSupported {
          camera.autoFocusRangeRestriction = .near
        }
        if camera.isSmoothAutoFocusSupported {
          camera.isSmoothAutoFocusEnabled = false
        }
        if camera.isFocusModeSupported(.continuousAutoFocus) {
          camera.focusMode = .continuousAutoFocus
        }

        if camera.isExposurePointOfInterestSupported {
          camera.exposurePointOfInterest = Self.scanCenter
        }
        if camera.isExposureModeSupported(.continuousAutoExposure) {
          camera.exposureMode = .continuousAutoExposure
        }
      } catch {
        return
      }
    }

    /// Returns the virtual-device zoom that matches its wide camera.
    ///
    /// A triple or dual-wide camera starts with the ultra-wide constituent.
    /// Moving to the wide constituent makes the QR larger, while automatic
    /// constituent switching can still use the ultra-wide lens for macro.
    private func wideAngleZoomFactor(
      for camera: AVCaptureDevice
    ) -> CGFloat {
      guard
        camera.isVirtualDevice,
        let wideIndex = camera.constituentDevices.firstIndex(where: {
          device in
          device.deviceType == .builtInWideAngleCamera
        })
      else {
        return camera.minAvailableVideoZoomFactor
      }

      let zoomFactor: CGFloat
      if wideIndex == 0 {
        zoomFactor = camera.minAvailableVideoZoomFactor
      } else {
        zoomFactor = CGFloat(
          truncating:
            camera.virtualDeviceSwitchOverVideoZoomFactors[
              wideIndex - 1
            ])
      }
      return min(
        max(zoomFactor, camera.minAvailableVideoZoomFactor),
        camera.maxAvailableVideoZoomFactor)
    }

    /// Starts the configured camera without blocking the main thread.
    internal func start() {
      queue.async { [self] in
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
      }
    }

    /// Applies torch state on the same queue that owns the session.
    internal func setTorchEnabled(_ enabled: Bool) {
      queue.async { [self] in
        guard let camera, camera.hasTorch else { return }
        do {
          try camera.lockForConfiguration()
          defer { camera.unlockForConfiguration() }
          if enabled, camera.isTorchAvailable,
            camera.isTorchModeSupported(.on)
          {
            camera.torchMode = .on
          } else if camera.isTorchModeSupported(.off) {
            camera.torchMode = .off
          }
        } catch {
          return
        }
      }
    }

    /// Refocuses the active virtual camera at a preview-space point.
    internal func focus(at devicePoint: CGPoint) {
      queue.async { [self] in
        guard let camera else { return }
        do {
          try camera.lockForConfiguration()
          defer { camera.unlockForConfiguration() }

          if camera.isFocusPointOfInterestSupported {
            camera.focusPointOfInterest = devicePoint
          }
          if camera.isFocusModeSupported(.continuousAutoFocus) {
            camera.focusMode = .continuousAutoFocus
          }
          if camera.isExposurePointOfInterestSupported {
            camera.exposurePointOfInterest = devicePoint
          }
          if camera.isExposureModeSupported(.continuousAutoExposure) {
            camera.exposureMode = .continuousAutoExposure
          }
        } catch {
          return
        }
      }
    }

    /// Turns the light off and stops producing frames.
    internal func stop() {
      queue.async { [self] in
        if let camera, camera.hasTorch,
          (try? camera.lockForConfiguration()) != nil
        {
          if camera.isTorchModeSupported(.off) {
            camera.torchMode = .off
          }
          camera.unlockForConfiguration()
        }
        if session.isRunning {
          session.stopRunning()
        }
        output.setSampleBufferDelegate(nil, queue: nil)
      }
    }
  }

#endif
