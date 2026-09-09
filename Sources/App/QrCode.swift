// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CoreImage
  import Foundation

  /// A QR code, drawn as vector rectangles rather than pixels.
  ///
  /// The modules are read out of the system's encoder and emitted as
  /// filled squares, so the code prints at the printer's resolution
  /// and stays sharp at any zoom - the same reason the handwriting is
  /// traced rather than placed as an image.
  internal enum QrCode {
    /// One encoded code: how many modules across, and which are dark.
    internal struct Modules {
      /// Modules per side.
      internal let side: Int

      /// Row-major, true where the module is dark.
      internal let dark: [Bool]

      /// A grid already assembled by a deterministic treatment.
      internal init?(side: Int, dark: [Bool]) {
        guard side > 0, dark.count == side * side else { return nil }
        self.side = side
        self.dark = dark
      }

      /// Reads the grid out of a rendered code, dropping the
      /// generator's own quiet zone so the page can choose its own
      /// margin.
      internal init?(rendered: Data, width: Int) {
        let across = width - QrCode.quietZone * QrCode.quietZoneSides
        guard across > 0, rendered.count >= width * width else { return nil }
        let pixels = Array(rendered)
        var found = [Bool](repeating: false, count: across * across)
        for row in 0..<across {
          for column in 0..<across {
            let source =
              (row + QrCode.quietZone) * width + column + QrCode.quietZone
            found[row * across + column] = pixels[source] < QrCode.darkLevel
          }
        }
        self.side = across
        self.dark = found
      }
    }

    /// The error correction the code carries.
    ///
    /// High correction carries the portrait-shaped module treatment
    /// and the red handwriting crossing it. The signed payload stays
    /// small enough that the stronger level remains printable.
    private static let correctionLevel = "H"

    /// The generator's own quiet zone, in modules, which is stripped
    /// so the page can decide its own margin.
    internal static let quietZone = 1

    /// Quiet zones to remove: one on each side.
    internal static let quietZoneSides = 2

    /// Grey level below which a module counts as dark: the midpoint
    /// of the range, since the generator draws in black and white.
    internal static let darkLevel = UInt8.max / UInt8(Self.quietZoneSides)

    /// Encodes bytes, or nil when they do not fit any QR code.
    internal static func modules(of payload: Data) -> Modules? {
      guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
      filter.setValue(payload, forKey: "inputMessage")
      filter.setValue(Self.correctionLevel, forKey: "inputCorrectionLevel")
      guard let output = filter.outputImage else { return nil }
      let context = CIContext(options: nil)
      let extent = output.extent
      guard
        extent.width > 0,
        let map = context.createCGImage(output, from: extent)
      else {
        return nil
      }
      let width = map.width
      var pixels = [UInt8](repeating: 0, count: width * map.height)
      guard
        let bitmap = CGContext(
          data: &pixels,
          width: width,
          height: map.height,
          bitsPerComponent: UInt8.bitWidth,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else {
        return nil
      }
      bitmap.draw(
        map, in: CGRect(x: 0, y: 0, width: width, height: map.height)
      )
      return Modules(rendered: Data(pixels), width: width)
    }

    /// PDF operators filling the dark modules inside a box `size`
    /// points square.
    ///
    /// Runs of dark modules in a row become one rectangle, which
    /// roughly halves the operators without changing what is drawn.
    internal static func pdfOperators(
      _ modules: Modules,
      size: Double,
      atX left: Double,
      atY bottom: Double
    ) -> String {
      let step = size / Double(modules.side)
      var body = ""
      for row in 0..<modules.side {
        var column = 0
        while column < modules.side {
          guard modules.dark[row * modules.side + column] else {
            column += 1
            continue
          }
          var run = 1
          while column + run < modules.side,
            modules.dark[row * modules.side + column + run]
          {
            run += 1
          }
          // PDF counts up from the bottom; the modules count down.
          let originY = bottom + size - Double(row + 1) * step
          body +=
            "\(left + Double(column) * step) \(originY)"
            + " \(step * Double(run)) \(step) re\n"
          column += run
        }
      }
      return body.isEmpty ? "" : body + "f\n"
    }
  }

#endif
