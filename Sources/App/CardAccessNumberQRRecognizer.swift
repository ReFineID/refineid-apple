// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  @preconcurrency import AVFoundation
  import CardCore
  @preconcurrency import Vision

  /// Decodes the structured CAN QR codes printed on Finnish ID cards.
  internal final class CardAccessNumberQRRecognizer:
    NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable
  {
    /// Leave enough space between Vision passes to keep the preview fluid.
    private static let recognitionIntervalNanoseconds: UInt64 = 150_000_000

    private let onRecognize: @MainActor @Sendable (String) -> Void
    private var hasRecognized = false
    private var lastRecognitionTime: UInt64 = 0

    /// Creates a recognizer that reports one parsed access number.
    internal init(
      onRecognize: @escaping @MainActor @Sendable (String) -> Void
    ) {
      self.onRecognize = onRecognize
    }

    /// Extracts a CAN only after the full QR payload passes its parser.
    private static func accessNumber(
      in imageBuffer: CVPixelBuffer
    ) -> String? {
      let request = VNDetectBarcodesRequest()
      request.symbologies = [.qr]

      do {
        try VNImageRequestHandler(
          cvPixelBuffer: imageBuffer,
          orientation: .up
        ).perform([request])
      } catch {
        return nil
      }

      for observation in request.results ?? [] {
        guard let payload = observation.payloadStringValue else { continue }
        if let digits = SecureMessagingBarcode.cardAccessNumberDigits(
          in: payload)
        {
          return digits
        }
      }
      return nil
    }

    internal func captureOutput(
      _: AVCaptureOutput,
      didOutput sampleBuffer: CMSampleBuffer,
      from _: AVCaptureConnection
    ) {
      guard !hasRecognized else { return }

      let now = DispatchTime.now().uptimeNanoseconds
      guard
        lastRecognitionTime == 0
          || now - lastRecognitionTime
            >= Self.recognitionIntervalNanoseconds
      else {
        return
      }
      lastRecognitionTime = now

      guard
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
        let digits = Self.accessNumber(in: imageBuffer)
      else {
        return
      }

      hasRecognized = true
      Task { @MainActor [onRecognize] in
        onRecognize(digits)
      }
    }
  }

#endif
