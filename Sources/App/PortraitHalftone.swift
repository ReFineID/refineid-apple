// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CoreImage
  import Foundation
  import Vision

  /// Reduces a DG2 portrait to the tonal grid used by the QR stipple.
  internal enum PortraitHalftone {
    /// Darkness values, row-major from the image's top edge.
    internal struct Map: Equatable, Sendable {
      internal let side: Int
      internal let darkness: [Double]
      internal let fieldSide: Int
      internal let fieldDarkness: [Double]

      internal init?(side: Int, darkness: [Double]) {
        self.init(
          side: side,
          darkness: darkness,
          fieldSide: side,
          fieldDarkness: darkness
        )
      }

      internal init?(
        side: Int,
        darkness: [Double],
        fieldSide: Int,
        fieldDarkness: [Double]
      ) {
        guard
          side > 0,
          darkness.count == side * side,
          fieldSide >= side,
          fieldDarkness.count == fieldSide * fieldSide,
          (fieldSide - side).isMultiple(of: PortraitHalftone.gridParity)
        else {
          return nil
        }
        self.side = side
        self.darkness = darkness
        self.fieldSide = fieldSide
        self.fieldDarkness = fieldDarkness
      }
    }

    /// Midpoint separating light and dark portrait targets.
    internal static let threshold = 0.5

    /// Full darkness in the normalised output.
    private static let fullDarkness = 1.0

    /// Sampling keeps narrow eyes, nostrils and mouth lines from being
    /// averaged away when the portrait becomes a small module grid.
    private static let samplesPerModule = 4
    private static let averageDarknessShare = 1.2
    private static let darkestSampleShare = 0.45
    private static let gridParity = 2

    /// The detected face fills nearly the complete stamp field.
    private static let faceMargin = 1.05

    /// Two, for taking half a crop dimension.
    private static let halves = 2.0

    /// Makes a square, high-contrast luminance map without retaining the
    /// biometric image beyond the in-memory stamp state.
    internal static func map(imageData: Data, side: Int) -> Map? {
      Self.map(imageData: imageData, side: side, fieldSide: side)
    }

    /// Makes one larger field whose central cells supply the QR portrait.
    internal static func map(
      imageData: Data,
      side: Int,
      fieldSide: Int
    ) -> Map? {
      guard
        side > 0,
        fieldSide >= side,
        (fieldSide - side).isMultiple(of: Self.gridParity),
        let input = CIImage(
          data: imageData,
          options: [.applyOrientationProperty: true]
        ),
        input.extent.width > 0,
        input.extent.height > 0,
        input.extent.width.isFinite,
        input.extent.height.isFinite,
        let portrait = Self.portraitImage(
          input,
          fieldScale: CGFloat(fieldSide) / CGFloat(side)
        )
      else {
        return nil
      }
      let fieldDarkness = Self.sampledDarkness(
        portrait,
        side: fieldSide
      )
      guard fieldDarkness.count == fieldSide * fieldSide else {
        return nil
      }
      let fieldInset = (fieldSide - side) / Self.gridParity
      let darkness = (0..<(side * side)).map { index in
        let row = index / side + fieldInset
        let column = index % side + fieldInset
        return fieldDarkness[row * fieldSide + column]
      }
      guard darkness.count == side * side else {
        return nil
      }
      return Map(
        side: side,
        darkness: darkness,
        fieldSide: fieldSide,
        fieldDarkness: fieldDarkness
      )
    }

    /// Samples a complete square field at sub-module resolution.
    private static func sampledDarkness(
      _ portrait: CGImage,
      side: Int
    ) -> [Double] {
      let sampleSide = side * Self.samplesPerModule
      var pixels = [UInt8](
        repeating: UInt8.max,
        count: sampleSide * sampleSide
      )
      guard
        let bitmap = CGContext(
          data: &pixels,
          width: sampleSide,
          height: sampleSide,
          bitsPerComponent: UInt8.bitWidth,
          bytesPerRow: sampleSide,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else {
        return []
      }
      bitmap.interpolationQuality = .high
      bitmap.draw(
        portrait,
        in: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide)
      )
      return (0..<(side * side)).map { index in
        Self.moduleDarkness(
          index: index,
          side: side,
          pixels: pixels,
          sampleSide: sampleSide
        )
      }
    }

    /// Blends average tone with the darkest sub-sample.
    ///
    /// The darkest value retains thin facial features in the final hedcut.
    private static func moduleDarkness(
      index: Int,
      side: Int,
      pixels: [UInt8],
      sampleSide: Int
    ) -> Double {
      let moduleRow = index / side
      let moduleColumn = index % side
      var sum = 0.0
      var darkest = 0.0
      for sampleRow in 0..<Self.samplesPerModule {
        for sampleColumn in 0..<Self.samplesPerModule {
          let row = moduleRow * Self.samplesPerModule + sampleRow
          let column = moduleColumn * Self.samplesPerModule + sampleColumn
          let darkness =
            Self.fullDarkness
            - Double(pixels[row * sampleSide + column]) / Double(UInt8.max)
          sum += darkness
          darkest = max(darkest, darkness)
        }
      }
      let sampleCount = Double(
        Self.samplesPerModule * Self.samplesPerModule
      )
      let average = sum / sampleCount
      return min(
        Self.fullDarkness,
        average * Self.averageDarknessShare
          + darkest * Self.darkestSampleShare
      )
    }

    /// Detects the holder's face locally and gives it almost the full square.
    ///
    /// A conventional crop remains available for malformed or unusual images
    /// where Vision finds no face.
    private static func portraitImage(
      _ image: CIImage,
      fieldScale: CGFloat
    ) -> CGImage? {
      let context = CIContext(options: [.useSoftwareRenderer: true])
      guard let source = context.createCGImage(image, from: image.extent) else {
        return nil
      }
      let qrCrop = Self.faceCrop(in: source) ?? Self.fallbackCrop(in: source)
      let crop =
        fieldScale > 1
        ? Self.expandedCrop(qrCrop, in: source, scale: fieldScale)
        : qrCrop
      return source.cropping(to: crop)
    }

    /// Reveals the source pixels around the face at the field's module scale.
    private static func expandedCrop(
      _ crop: CGRect,
      in image: CGImage,
      scale: CGFloat
    ) -> CGRect {
      let imageWidth = CGFloat(image.width)
      let imageHeight = CGFloat(image.height)
      let side = min(
        min(imageWidth, imageHeight),
        crop.width * scale
      )
      let originX = min(
        max(0, crop.midX - side / Self.halves),
        imageWidth - side
      )
      let originY = min(
        max(0, crop.midY - side / Self.halves),
        imageHeight - side
      )
      return CGRect(x: originX, y: originY, width: side, height: side)
        .integral
    }

    /// A square around the largest detected face with minimal margin.
    private static func faceCrop(in image: CGImage) -> CGRect? {
      let request = VNDetectFaceRectanglesRequest()
      guard
        (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil,
        let face = request.results?.max(by: { left, right in
          left.boundingBox.width * left.boundingBox.height
            < right.boundingBox.width * right.boundingBox.height
        })
      else {
        return nil
      }
      let imageWidth = CGFloat(image.width)
      let imageHeight = CGFloat(image.height)
      let bounds = face.boundingBox
      let faceRectangle = CGRect(
        x: bounds.minX * imageWidth,
        y: (1 - bounds.maxY) * imageHeight,
        width: bounds.width * imageWidth,
        height: bounds.height * imageHeight
      )
      let side = min(
        min(imageWidth, imageHeight),
        max(faceRectangle.width, faceRectangle.height) * Self.faceMargin
      )
      let originX = min(
        max(0, faceRectangle.midX - side / Self.halves),
        imageWidth - side
      )
      let originY = min(
        max(0, faceRectangle.midY - side / Self.halves),
        imageHeight - side
      )
      return CGRect(x: originX, y: originY, width: side, height: side)
        .integral
    }

    /// The upper square of an ICAO-style portrait retains more face than
    /// a centre crop, which spends pixels on shoulders below the holder.
    private static func fallbackCrop(in image: CGImage) -> CGRect {
      let width = CGFloat(image.width)
      let side = CGFloat(min(image.width, image.height))
      return CGRect(
        x: (width - side) / Self.halves,
        y: 0,
        width: side,
        height: side
      )
    }
  }

#endif
