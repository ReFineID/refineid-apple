// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import AppKit
  import CardCore
  import Foundation

  /// Turns the card's signature image into scalable PDF artwork.
  ///
  /// The card stores a small JPEG. Placed in a page as a JPEG it
  /// would be fixed at that resolution and would carry an opaque
  /// white box; traced it becomes a drawing that scales, prints at
  /// the printer's resolution, and paints only where the ink is.
  ///
  /// The threshold is deliberately generous. A JPEG of black ink on
  /// white paper has soft grey edges from its own compression, and a
  /// threshold near the middle keeps the stroke's shape without
  /// picking up the ringing around it.
  internal enum SignatureArtwork {
    /// One traced signature, ready to be placed in a page.
    internal struct Artwork {
      /// PDF path operators filling the outlines, in a box of
      /// `width` by `height` points.
      internal let operators: String

      /// The natural width of that box, in image pixels.
      internal let width: Double

      /// The natural height, in image pixels.
      internal let height: Double

      /// Where the ink actually is, in the same coordinates the
      /// operators use: PDF's, counting up from the bottom.
      ///
      /// The card's image has blank margins around the writing, and
      /// they are not the same on every card. Placing the box would
      /// place the margins; placing this places the writing.
      internal let inkLeft: Double
      internal let inkRight: Double
      internal let inkBottom: Double
      internal let inkTop: Double
    }

    /// Grey level below which a pixel counts as ink.
    private static let inkThreshold: UInt8 = 128

    /// How far, in pixels, a traced vertex may be moved to simplify
    /// the outline.
    private static let traceTolerance = 0.8

    /// Decimal places kept in the emitted coordinates: the card's
    /// image is a pixel grid, so tenths already describe it exactly.
    private static let coordinateDecimals = 1

    /// Traces an encoded image into path operators, or nil when the
    /// bytes do not decode or hold no ink.
    internal static func traced(_ encoded: Data) -> Artwork? {
      guard let bitmap = Self.bilevel(encoded) else { return nil }
      let outlines = InkOutline.simplified(
        InkOutline.trace(bitmap), tolerance: Self.traceTolerance
      )
      guard !outlines.isEmpty else { return nil }
      let operators = InkOutline.pdfOperators(
        outlines,
        height: Double(bitmap.height),
        decimals: Self.coordinateDecimals
      )
      let across = outlines.flatMap { outline in outline.map(\.across) }
      let down = outlines.flatMap { outline in outline.map(\.down) }
      guard
        let left = across.min(), let right = across.max(),
        let top = down.min(), let bottom = down.max()
      else {
        return nil
      }
      let height = Double(bitmap.height)
      return Artwork(
        operators: operators,
        width: Double(bitmap.width),
        height: height,
        inkLeft: left,
        inkRight: right,
        inkBottom: height - bottom,
        inkTop: height - top
      )
    }

    /// Decodes the image and thresholds it to ink and paper.
    private static func bilevel(_ encoded: Data) -> InkOutline.Bitmap? {
      guard
        let image = NSImage(data: encoded),
        let cgImage = image.cgImage(
          forProposedRect: nil, context: nil, hints: nil
        )
      else {
        return nil
      }
      let width = cgImage.width
      let height = cgImage.height
      guard width > 0, height > 0 else { return nil }
      var grey = [UInt8](repeating: 0, count: width * height)
      guard
        let context = CGContext(
          data: &grey,
          width: width,
          height: height,
          bitsPerComponent: UInt8.bitWidth,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else {
        return nil
      }
      context.draw(
        cgImage,
        in: CGRect(x: 0, y: 0, width: width, height: height)
      )
      // A bitmap context's memory runs top row first, whatever its
      // drawing origin, and the tracer counts rows from the top too -
      // so the rows are read straight through. Flipping them here,
      // reasoning from the drawing origin rather than the memory
      // layout, put the signature on the page upside down.
      let ink = grey.map { level in level < Self.inkThreshold }
      return InkOutline.Bitmap(width: width, height: height, ink: ink)
    }
  }

#endif
