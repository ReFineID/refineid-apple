// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  /// Extends the QR's mixed dot resolution beyond its encoded cells.
  extension StampRenderer {
    /// The published SplitMix64 increment and avalanche multipliers.
    private static let portraitPatternSeed: UInt64 = 11_400_714_819_323_198_485
    private static let portraitPatternRowMix: UInt64 = 13_787_848_793_156_543_929
    private static let portraitPatternColumnMix: UInt64 = 10_723_151_780_598_845_931
    private static let portraitPatternFirstShift: UInt64 = 30
    private static let portraitPatternSecondShift: UInt64 = 27
    private static let portraitPatternFinalShift: UInt64 = 31
    private static let portraitPatternBucketCount: UInt64 = 10
    private static let portraitPatternCentralDotBuckets: UInt64 = 4

    /// Certificate names following the upper and lower inner arcs.
    private static let portraitNameFont = "Helvetica"
    private static let portraitNameSize = 10.5
    private static let portraitGivenNameRadius = 58.5
    private static let portraitGivenNameTracking = 1.1
    private static let portraitSurnameRadius = 64.0
    private static let portraitSurnameTracking = 0.6
    private static let portraitNameMaximumSpan = 1.45

    /// A stable choice between one central and four small dots.
    internal static func portraitExtensionUsesCentralDot(
      row: Int,
      column: Int
    ) -> Bool {
      var pattern = Self.portraitPatternSeed
      pattern ^= UInt64(row) &* Self.portraitPatternRowMix
      pattern ^= UInt64(column) &* Self.portraitPatternColumnMix
      pattern ^= pattern >> Self.portraitPatternFirstShift
      pattern &*= Self.portraitPatternRowMix
      pattern ^= pattern >> Self.portraitPatternSecondShift
      pattern &*= Self.portraitPatternColumnMix
      pattern ^= pattern >> Self.portraitPatternFinalShift
      return
        pattern % Self.portraitPatternBucketCount
        < Self.portraitPatternCentralDotBuckets
    }

    /// Given name above and surname below, both as curved vector outlines.
    internal static func portraitCurvedNames(
      givenName: String,
      surname: String
    ) -> String {
      let given = TextOutline.curvedLine(
        givenName.uppercased(),
        curve: TextOutline.Curve(
          font: Self.portraitNameFont,
          size: Self.portraitNameSize,
          radius: Self.portraitGivenNameRadius,
          tracking: Self.portraitGivenNameTracking,
          maximumSpan: Self.portraitNameMaximumSpan,
          arc: .top
        )
      )
      let family = TextOutline.curvedLine(
        surname.uppercased(),
        curve: TextOutline.Curve(
          font: Self.portraitNameFont,
          size: Self.portraitNameSize,
          radius: Self.portraitSurnameRadius,
          tracking: Self.portraitSurnameTracking,
          maximumSpan: Self.portraitNameMaximumSpan,
          arc: .bottom
        )
      )
      return given + family
    }
  }

#endif
