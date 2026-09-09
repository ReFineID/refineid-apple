// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Renders the visual red electronic signature stamp.
///
/// The stamp advises verifying the electronic signature of the signed file.
/// Vector operators center on the origin and use standard PDF typography.
public enum PdfStampRenderer {
  internal struct StampTexts: Sendable {
    internal let middleLines: [String]
    internal let topBorderText: String
    internal let bottomBorderText: String
  }

  /// The outer circular radius of the stamp in points.
  public static let stampRadius = 64.0
  /// The bleed margin in points for line strokes.
  public static let stampBleed = 2.0
  /// The total reach from center including stroke bleed.
  public static let stampReach = 66.0

  private static let borderInnerRadius = 48.0
  private static let inkColor = "0.7765 0.1569 0.1569"
  private static let circleKappa = 0.5522847498307935

  private static let outerRingLineWidth = 1.8
  private static let borderSeparatorLineWidth = 0.9
  private static let innerRingLineWidth = 0.5
  private static let subtleRingOffset = 3.0
  private static let arcTextRadius = 55.5
  private static let topStartAngleDegrees = 168.0
  private static let topSweepAngleDegrees = -156.0
  private static let bottomStartAngleDegrees = -168.0
  private static let bottomSweepAngleDegrees = 156.0
  private static let semiCircleDegrees = 180.0
  private static let degreesToRadians = Double.pi / semiCircleDegrees
  private static let topStartAngle = topStartAngleDegrees * degreesToRadians
  private static let topSweepAngle = topSweepAngleDegrees * degreesToRadians
  private static let bottomStartAngle = bottomStartAngleDegrees * degreesToRadians
  private static let bottomSweepAngle = bottomSweepAngleDegrees * degreesToRadians
  private static let rightAngle = Double.pi * half
  private static let half = 0.5

  private static let bulletFontSize = 4.5
  private static let bulletOffset = 1.0
  private static let bulletRightOffset = 2.0
  private static let bulletY = -1.50

  private static let centerFontSize = 5.2
  private static let centerLineHeightFactor = 1.45
  private static let centerStartYFactor = 0.3
  private static let centerCharWidthFactor = 0.56

  private static let longCharThreshold = 40
  private static let mediumCharThreshold = 30
  private static let smallFontSize = 2.9
  private static let mediumFontSize = 3.3
  private static let largeFontSize = 3.6

  private static let asciiPrintableMin: UInt8 = 32
  private static let asciiPrintableMax: UInt8 = 126
  private static let octalByteModulus = 256

  private static let specialEscapes: [Character: String] = [
    "(": "\\(",
    ")": "\\)",
    "\\": "\\\\",
    "\u{00E4}": "\\344",
    "\u{00F6}": "\\366",
    "\u{00E5}": "\\345",
    "\u{00C4}": "\\304",
    "\u{00D6}": "\\326",
    "\u{00C5}": "\\305",
    "\u{2022}": "\\225",
  ]

  /// Creates a ready-to-place stamp mark with the localized advice.
  public static func stampMark(locale: Locale = .current) -> StampMark {
    StampMark(
      radius: stampRadius,
      operators: generateStampOperators(locale: locale)
    )
  }

  /// Generates the PDF graphics stream operators drawing the complete stamp.
  public static func generateStampOperators(locale: Locale = .current) -> String {
    var output = "q\n"
    output += "\(inkColor) RG \(inkColor) rg\n"
    appendRings(into: &output)
    let stampTexts = resolveStampTexts(locale: locale)
    appendTopArc(into: &output, text: stampTexts.topBorderText)
    appendBottomArc(into: &output, text: stampTexts.bottomBorderText)
    appendBullets(into: &output)
    appendCenterLines(into: &output, lines: stampTexts.middleLines)
    output += "Q\n"
    return output
  }

  private static func appendRings(into output: inout String) {
    output += "\(outerRingLineWidth) w\n"
    appendCircle(into: &output, radius: stampRadius)
    output += "S\n"

    output += "\(borderSeparatorLineWidth) w\n"
    appendCircle(into: &output, radius: borderInnerRadius)
    output += "S\n"

    output += "\(innerRingLineWidth) w\n"
    appendCircle(into: &output, radius: borderInnerRadius - subtleRingOffset)
    output += "S\n"
  }

  private static func appendTopArc(into output: inout String, text: String) {
    let characters = Array(text)
    let count = characters.count
    let fontSize = calculatePdfFontSize(characterCount: count)

    output += "BT\n"
    output += String(format: "/F1 %.1f Tf\n", fontSize)
    for index in characters.indices {
      let fraction = count > 1 ? Double(index) / Double(count - 1) : half
      let angle = topStartAngle + fraction * topSweepAngle
      let pointX = arcTextRadius * cos(angle)
      let pointY = arcTextRadius * sin(angle)

      let textAngle = angle - rightAngle
      let cosA = cos(textAngle)
      let sinA = sin(textAngle)

      output += String(
        format: "%.4f %.4f %.4f %.4f %.2f %.2f Tm\n",
        cosA, sinA, -sinA, cosA, pointX, pointY
      )
      output += "(\(escapePdfString(characters[index]))) Tj\n"
    }
  }

  private static func appendBottomArc(into output: inout String, text: String) {
    let characters = Array(text)
    let count = characters.count
    let fontSize = calculatePdfFontSize(characterCount: count)

    output += String(format: "/F1 %.1f Tf\n", fontSize)
    for index in characters.indices {
      let fraction = count > 1 ? Double(index) / Double(count - 1) : half
      let angle = bottomStartAngle + fraction * bottomSweepAngle
      let pointX = arcTextRadius * cos(angle)
      let pointY = arcTextRadius * sin(angle)

      let textAngle = angle + rightAngle
      let cosA = cos(textAngle)
      let sinA = sin(textAngle)

      output += String(
        format: "%.4f %.4f %.4f %.4f %.2f %.2f Tm\n",
        cosA, sinA, -sinA, cosA, pointX, pointY
      )
      output += "(\(escapePdfString(characters[index]))) Tj\n"
    }
  }

  private static func appendBullets(into output: inout String) {
    output += String(format: "/F1 %.1f Tf\n", bulletFontSize)
    output += String(
      format: "1.0000 0.0000 0.0000 1.0000 %.2f %.2f Tm\n",
      -arcTextRadius - bulletOffset,
      bulletY
    )
    output += "(\\225) Tj\n"
    output += String(
      format: "1.0000 0.0000 0.0000 1.0000 %.2f %.2f Tm\n",
      arcTextRadius - bulletRightOffset,
      bulletY
    )
    output += "(\\225) Tj\n"
    output += "ET\n"
  }

  private static func appendCenterLines(into output: inout String, lines: [String]) {
    let lineHeight = centerFontSize * centerLineHeightFactor
    let totalHeight = Double(lines.count - 1) * lineHeight
    let startY = (totalHeight * half) - (centerFontSize * centerStartYFactor)

    output += "BT\n"
    output += String(format: "/F1 %.1f Tf\n", centerFontSize)
    for (index, line) in lines.enumerated() {
      let pointY = startY - Double(index) * lineHeight
      let approxWidth = Double(line.count) * (centerFontSize * centerCharWidthFactor)
      let pointX = -(approxWidth * half)
      output += String(
        format: "1.0000 0.0000 0.0000 1.0000 %.2f %.2f Tm\n",
        pointX, pointY
      )
      let escapedLine = line.map(escapePdfString).joined()
      output += "(\(escapedLine)) Tj\n"
    }
    output += "ET\n"
  }

  internal static func resolveStampTexts(locale: Locale) -> StampTexts {
    let language = locale.language.languageCode?.identifier.lowercased() ?? "en"
    let fiTitle = ["TARKASTA ASIAKIRJAN", "S\u{00C4}HK\u{00D6}INEN", "ALLEKIRJOITUS"]
    let svTitle = ["KONTROLLERA DOKUMENTETS", "ELEKTRONISKA", "SIGNATUR"]
    let enTitle = ["CHECK DOCUMENT", "ELECTRONIC", "SIGNATURE"]

    let fiBorder = "TARKASTA ASIAKIRJAN S\u{00C4}HK\u{00D6}INEN ALLEKIRJOITUS"
    let svBorder = "KONTROLLERA DOKUMENTETS ELEKTRONISKA SIGNATUR"
    let enBorder = "CHECK DOCUMENT ELECTRONIC SIGNATURE"

    switch language {
    case "sv":
      return StampTexts(
        middleLines: svTitle,
        topBorderText: fiBorder,
        bottomBorderText: enBorder
      )

    case "fi":
      return StampTexts(
        middleLines: fiTitle,
        topBorderText: svBorder,
        bottomBorderText: enBorder
      )

    default:
      return StampTexts(
        middleLines: enTitle,
        topBorderText: fiBorder,
        bottomBorderText: svBorder
      )
    }
  }

  private static func calculatePdfFontSize(characterCount: Int) -> Double {
    if characterCount > longCharThreshold {
      smallFontSize
    } else if characterCount > mediumCharThreshold {
      mediumFontSize
    } else {
      largeFontSize
    }
  }

  private static func appendCircle(into output: inout String, radius: Double) {
    let controlOffset = radius * circleKappa
    output += String(format: "%.2f 0.00 m\n", radius)
    output += String(
      format: "%.2f %.2f %.2f %.2f 0.00 %.2f c\n",
      radius, controlOffset, controlOffset, radius, radius
    )
    output += String(
      format: "-%.2f %.2f -%.2f %.2f -%.2f 0.00 c\n",
      controlOffset, radius, radius, controlOffset, radius
    )
    output += String(
      format: "-%.2f -%.2f -%.2f -%.2f 0.00 -%.2f c\n",
      radius, controlOffset, controlOffset, radius, radius
    )
    output += String(
      format: "%.2f -%.2f %.2f -%.2f %.2f 0.00 c\n",
      controlOffset, radius, radius, controlOffset, radius
    )
  }

  private static func escapePdfString(_ character: Character) -> String {
    if let escaped = specialEscapes[character] {
      return escaped
    }
    guard let ascii = character.asciiValue else {
      if let scalar = character.unicodeScalars.first {
        return String(format: "\\%03o", Int(scalar.value) % octalByteModulus)
      }
      return String(character)
    }
    if ascii >= asciiPrintableMin, ascii <= asciiPrintableMax {
      return String(character)
    }
    return String(format: "\\%03o", ascii)
  }
}
