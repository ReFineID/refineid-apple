// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import Foundation

  /// The portrait QR variant, kept apart from the identity-only mark.
  extension StampRenderer {
    /// The two red rings around the machine-readable square.
    private static let portraitOuterRadius = 72.0
    private static let portraitInnerRadius = 69.0
    private static let portraitOuterLineWidth = 1.8
    private static let portraitInnerLineWidth = 0.9

    /// The portrait QR itself fills this square without a rectangular border.
    private static let portraitSquareSize = 100.0

    /// The red handwriting fills the inner circle across its centre.
    private static let portraitSignatureWidth = 128.0
    private static let portraitSignatureHeight = 30.0

    /// Dot-size controls that translate tone into hedcut density.
    private static let dataDotBaseRadius = 0.08
    private static let dataDotDarknessShare = 0.42
    private static let peripheralDotThreshold = 0.12
    private static let peripheralDotMaximumRadius = 0.20
    private static let peripheralDotBaseRadius = 0.0
    private static let peripheralDotDarknessShare = 0.20
    private static let peripheralDotOffset = 0.27
    private static let extensionDotThreshold = 0.03
    private static let extensionToneScale = 0.96
    private static let functionDotBaseRadius = 0.36
    private static let functionDotDarknessShare = 0.14

    /// Geometry constants shared by the rings and dots.
    private static let portraitArcControl = 0.5523
    private static let portraitQuarterTurns = 4
    private static let portraitHalves = 2.0
    private static let portraitGridParity = 2
    private static let portraitHalfModule = 0.5
    private static let portraitQuarterTurn = Double.pi / portraitHalves

    /// The mark's colour, #B02020, as PDF fractions.
    private static let portraitInkColour = "0.6902 0.1255 0.1255"

    /// A rubber-stamp turn, deliberately far enough from square to look set.
    private static let portraitLeastTilt = 10.0
    private static let portraitMostTilt = 20.0
    private static let portraitHalfTurnDegrees = 180.0

    /// The larger portrait grid required to reach the inner red ring while
    /// keeping the QR itself square and untouched.
    internal static func portraitFieldSide(forQrSide qrSide: Int) -> Int? {
      guard qrSide > 0 else { return nil }
      let module = Self.portraitSquareSize / Double(qrSide)
      var fieldSide = Int(
        ceil(Self.portraitInnerRadius * Self.portraitHalves / module)
      )
      if !(fieldSide - qrSide).isMultiple(of: Self.portraitGridParity) {
        fieldSide += 1
      }
      return max(qrSide, fieldSide)
    }

    /// A complete round stamp containing the portrait QR and, when present,
    /// the card's handwriting.
    internal static func portraitMark(
      _ artwork: QrPortrait.Artwork,
      signature: SignatureArtwork.Artwork?,
      givenName: String,
      surname: String
    ) -> StampMark {
      let centre = (horizontal: 0.0, vertical: 0.0)
      var body = "q\n"
      body += Self.portraitTilt()
      body += Self.portraitQr(artwork, centre: centre)
      body += "\(Self.portraitInkColour) RG"
      body += " \(Self.portraitInkColour) rg\n"
      body += Self.portraitCircle(
        radius: Self.portraitOuterRadius,
        lineWidth: Self.portraitOuterLineWidth
      )
      body += Self.portraitCircle(
        radius: Self.portraitInnerRadius,
        lineWidth: Self.portraitInnerLineWidth
      )
      if let signature {
        body += Self.handwritingAcrossPortraitQr(signature)
      }
      body += Self.portraitCurvedNames(
        givenName: givenName,
        surname: surname
      )
      body += "Q\nQ\n"
      return StampMark(radius: Self.portraitOuterRadius, operators: body)
    }

    /// The black portrait-stippled QR and its circular hedcut extension.
    private static func portraitQr(
      _ artwork: QrPortrait.Artwork,
      centre: (horizontal: Double, vertical: Double)
    ) -> String {
      guard
        artwork.side > 0,
        artwork.fieldSide >= artwork.side,
        artwork.fieldDarkness.count == artwork.fieldSide * artwork.fieldSide
      else {
        return ""
      }
      let module = Self.portraitSquareSize / Double(artwork.side)
      let codeSize = module * Double(artwork.side)
      let left = centre.horizontal - codeSize / Self.portraitHalves
      let bottom = centre.vertical - codeSize / Self.portraitHalves
      var body = "q\n"
      body += Self.portraitClip(radius: Self.portraitInnerRadius)
      body += "0 0 0 rg\n"
      body += Self.portraitField(
        artwork,
        centre: centre,
        module: module
      )
      body += Self.qrBackground(centre: centre)
      for row in 0..<artwork.side {
        for column in 0..<artwork.side {
          body += Self.portraitModule(
            artwork,
            row: row,
            column: column,
            origin: (horizontal: left, vertical: bottom),
            module: module
          )
        }
      }
      return body + "Q\n"
    }

    /// Extends the same sampled portrait across the circular stamp field.
    private static func portraitField(
      _ artwork: QrPortrait.Artwork,
      centre: (horizontal: Double, vertical: Double),
      module: Double
    ) -> String {
      let fieldSize = module * Double(artwork.fieldSide)
      let origin = (
        horizontal: centre.horizontal - fieldSize / Self.portraitHalves,
        vertical: centre.vertical - fieldSize / Self.portraitHalves
      )
      let codeHalf = Self.portraitSquareSize / Self.portraitHalves
      let radiusSquared = Self.portraitInnerRadius * Self.portraitInnerRadius
      var body = ""
      for row in 0..<artwork.fieldSide {
        for column in 0..<artwork.fieldSide {
          let point = (
            horizontal: origin.horizontal
              + (Double(column) + Self.portraitHalfModule) * module,
            vertical: origin.vertical
              + (Double(artwork.fieldSide - row) - Self.portraitHalfModule)
              * module
          )
          let relativeX = point.horizontal - centre.horizontal
          let relativeY = point.vertical - centre.vertical
          guard
            relativeX * relativeX + relativeY * relativeY <= radiusSquared,
            abs(relativeX) > codeHalf || abs(relativeY) > codeHalf
          else {
            continue
          }
          let darkness =
            artwork.fieldDarkness[row * artwork.fieldSide + column]
            * Self.extensionToneScale
          guard darkness > Self.extensionDotThreshold else { continue }
          if Self.portraitExtensionUsesCentralDot(row: row, column: column) {
            let radius =
              module
              * (Self.dataDotBaseRadius
                + Self.dataDotDarknessShare * darkness)
            body += Self.portraitFilledCircle(centre: point, radius: radius)
          } else if darkness > Self.peripheralDotThreshold {
            body += Self.peripheralDots(
              centre: point,
              darkness: darkness,
              module: module
            )
          }
        }
      }
      return body
    }

    /// Gives the QR light modules an opaque background, with no outer border.
    private static func qrBackground(centre: (horizontal: Double, vertical: Double)) -> String {
      let left = centre.horizontal - Self.portraitSquareSize / Self.portraitHalves
      let bottom = centre.vertical - Self.portraitSquareSize / Self.portraitHalves
      var body = "1 1 1 rg \(Self.portraitNumber(left))"
      body += " \(Self.portraitNumber(bottom))"
      body += " \(Self.portraitNumber(Self.portraitSquareSize))"
      body += " \(Self.portraitNumber(Self.portraitSquareSize)) re f\n"
      return body + "0 0 0 rg\n"
    }

    /// Clips the portrait field at the inner ring; the rings are drawn later.
    private static func portraitClip(radius: Double) -> String {
      var body = "\(Self.portraitNumber(radius)) 0.0000 m\n"
      body += Self.portraitCircleCurves(radius: radius)
      return body + "h W n\n"
    }

    /// One structural square, data dot, or peripheral stipple cluster.
    private static func portraitModule(
      _ artwork: QrPortrait.Artwork,
      row: Int,
      column: Int,
      origin: (horizontal: Double, vertical: Double),
      module: Double
    ) -> String {
      let index = row * artwork.side + column
      let centre = (
        horizontal: origin.horizontal + (Double(column) + Self.portraitHalfModule) * module,
        vertical: origin.vertical
          + (Double(artwork.side - row) - Self.portraitHalfModule) * module
      )
      if artwork.functionModules[index] {
        guard artwork.treated[index] else { return "" }
        return Self.functionModule(
          centre: centre,
          side: module,
          darkness: artwork.darkness[index]
        )
      }
      if artwork.treated[index] {
        let radius =
          module
          * (Self.dataDotBaseRadius
            + Self.dataDotDarknessShare * artwork.darkness[index])
        return Self.portraitFilledCircle(centre: centre, radius: radius)
      }
      guard
        artwork.darkness[index] > Self.peripheralDotThreshold,
        artwork.treated[index] == artwork.original[index]
      else {
        return ""
      }
      return Self.peripheralDots(
        centre: centre,
        darkness: artwork.darkness[index],
        module: module
      )
    }

    /// One circular structural module, still shaped by the portrait tone.
    private static func functionModule(
      centre: (horizontal: Double, vertical: Double),
      side: Double,
      darkness: Double
    ) -> String {
      let radius =
        side
        * (Self.functionDotBaseRadius
          + Self.functionDotDarknessShare * darkness)
      return Self.portraitFilledCircle(centre: centre, radius: radius)
    }

    /// Four tiny dots that add tone without changing a light QR module.
    private static func peripheralDots(
      centre: (horizontal: Double, vertical: Double),
      darkness: Double,
      module: Double
    ) -> String {
      let radius =
        module
        * min(
          Self.peripheralDotMaximumRadius,
          Self.peripheralDotBaseRadius
            + darkness * Self.peripheralDotDarknessShare
        )
      let offset = module * Self.peripheralDotOffset
      var body = ""
      for shiftX in [-offset, offset] {
        for shiftY in [-offset, offset] {
          body += Self.portraitFilledCircle(
            centre: (centre.horizontal + shiftX, centre.vertical + shiftY),
            radius: radius
          )
        }
      }
      return body
    }

    /// The holder's handwriting across the QR, with no baseline or name.
    private static func handwritingAcrossPortraitQr(
      _ artwork: SignatureArtwork.Artwork
    ) -> String {
      let inkWidth = artwork.inkRight - artwork.inkLeft
      let inkHeight = artwork.inkTop - artwork.inkBottom
      guard inkWidth > 0, inkHeight > 0 else { return "" }
      let scale = min(
        Self.portraitSignatureWidth / inkWidth,
        Self.portraitSignatureHeight / inkHeight
      )
      let left = -(inkWidth * scale) / Self.portraitHalves
      let bottom =
        -(artwork.inkBottom + inkHeight / Self.portraitHalves) * scale
      var body = "q \(Self.portraitNumber(scale)) 0 0"
      body += " \(Self.portraitNumber(scale))"
      body += " \(Self.portraitNumber(left - artwork.inkLeft * scale))"
      body += " \(Self.portraitNumber(bottom)) cm\n"
      body += artwork.operators
      return body + "Q\n"
    }

    /// A circle used for one red ring.
    private static func portraitCircle(radius: Double, lineWidth: Double) -> String {
      var body = "\(Self.portraitNumber(lineWidth)) w\n"
      body += "\(Self.portraitNumber(radius)) 0.0000 m\n"
      body += Self.portraitCircleCurves(radius: radius)
      return body + "h\nS\n"
    }

    /// A filled circle used for one hedcut dot.
    private static func portraitFilledCircle(
      centre: (horizontal: Double, vertical: Double),
      radius: Double
    ) -> String {
      var body = "\(Self.portraitNumber(centre.horizontal + radius))"
      body += " \(Self.portraitNumber(centre.vertical)) m\n"
      body += Self.portraitCircleCurves(radius: radius, centre: centre)
      return body + "h f\n"
    }

    /// Four Bezier quarters, optionally translated from the origin.
    private static func portraitCircleCurves(
      radius: Double,
      centre: (horizontal: Double, vertical: Double) = (0, 0)
    ) -> String {
      let pull = Self.portraitArcControl * radius
      var body = ""
      for quarter in 0..<Self.portraitQuarterTurns {
        let opens = Double(quarter) * Self.portraitQuarterTurn
        let closes = opens + Self.portraitQuarterTurn
        let start = Self.portraitPoint(centre, radius: radius, angle: opens)
        let end = Self.portraitPoint(centre, radius: radius, angle: closes)
        let leaving = (
          horizontal: start.horizontal - pull * sin(opens),
          vertical: start.vertical + pull * cos(opens)
        )
        let arriving = (
          horizontal: end.horizontal + pull * sin(closes),
          vertical: end.vertical - pull * cos(closes)
        )
        body += "\(Self.portraitNumber(leaving.horizontal))"
        body += " \(Self.portraitNumber(leaving.vertical))"
        body += " \(Self.portraitNumber(arriving.horizontal))"
        body += " \(Self.portraitNumber(arriving.vertical))"
        body += " \(Self.portraitNumber(end.horizontal))"
        body += " \(Self.portraitNumber(end.vertical)) c\n"
      }
      return body
    }

    /// One point on a circle.
    private static func portraitPoint(
      _ centre: (horizontal: Double, vertical: Double),
      radius: Double,
      angle: Double
    ) -> (horizontal: Double, vertical: Double) {
      (
        horizontal: centre.horizontal + radius * cos(angle),
        vertical: centre.vertical + radius * sin(angle)
      )
    }

    /// The random clockwise transform applied to the whole stamp.
    private static func portraitTilt() -> String {
      let degrees = Double.random(
        in: Self.portraitLeastTilt...Self.portraitMostTilt
      )
      let turn = -degrees * Double.pi / Self.portraitHalfTurnDegrees
      let cosine = cos(turn)
      let sine = sin(turn)
      return "q \(Self.portraitNumber(cosine)) \(Self.portraitNumber(sine))"
        + " \(Self.portraitNumber(-sine)) \(Self.portraitNumber(cosine))"
        + " 0.0000 0.0000 cm\n"
    }

    /// One number in PDF decimal notation.
    private static func portraitNumber(_ value: Double) -> String {
      String(format: "%.4f", value)
    }
  }

#endif
