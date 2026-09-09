// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

@Suite
internal struct PdfStampRendererTests {
  @Test
  internal func stampMarkProducesExpectedGeometry() {
    let mark = PdfStampRenderer.stampMark(locale: Locale(identifier: "en_US"))
    #expect(mark.radius == 64.0)
    #expect(mark.reach == 68.0)
    #expect(!mark.operators.isEmpty)
    #expect(mark.operators.contains("0.7765 0.1569 0.1569 RG"))
  }

  @Test
  internal func localizedTextsMatchLanguages() {
    let fiTexts = PdfStampRenderer.resolveStampTexts(locale: Locale(identifier: "fi_FI"))
    #expect(fiTexts.middleLines.contains("TARKASTA ASIAKIRJAN"))
    #expect(fiTexts.bottomBorderText == "CHECK DOCUMENT ELECTRONIC SIGNATURE")

    let svTexts = PdfStampRenderer.resolveStampTexts(locale: Locale(identifier: "sv_SE"))
    #expect(svTexts.middleLines.contains("KONTROLLERA DOKUMENTETS"))
    #expect(svTexts.bottomBorderText == "CHECK DOCUMENT ELECTRONIC SIGNATURE")

    let enTexts = PdfStampRenderer.resolveStampTexts(locale: Locale(identifier: "en_US"))
    #expect(enTexts.middleLines.contains("CHECK DOCUMENT"))
    #expect(enTexts.bottomBorderText == "KONTROLLERA DOKUMENTETS ELEKTRONISKA SIGNATUR")
  }

  @Test
  internal func generatedOperatorsContainFontsAndCenterText() {
    let operators = PdfStampRenderer.generateStampOperators(locale: Locale(identifier: "fi_FI"))
    #expect(operators.contains("/F1"))
    #expect(operators.contains("Tj"))
    #expect(operators.hasPrefix("q\n"))
    #expect(operators.hasSuffix("Q\n"))
  }
}
