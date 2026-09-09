// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import Foundation

  /// Sizes and moves a mark into clear space on the last page.
  internal enum StampPlacement {
    /// Places an ordinary mark, allowing the page search to shrink it.
    internal static func placed(
      _ mark: StampMark?,
      on document: Data
    ) -> StampMark? {
      guard let mark else { return nil }
      return Self.composed(
        mark,
        at: StampSpot.free(inLastPageOf: document, reach: mark.reach)
      )
    }

    /// Places machine-readable detail without going below its safe scale.
    internal static func placed(
      _ mark: StampMark?,
      on document: Data,
      minimumShare: Double
    ) -> StampMark? {
      guard let mark else { return nil }
      return Self.composed(
        mark,
        at: StampSpot.free(
          inLastPageOf: document,
          reach: mark.reach,
          minimumShare: minimumShare
        )
      )
    }

    /// Applies one chosen spot, or leaves the mark at its PDF fallback.
    private static func composed(
      _ mark: StampMark,
      at spot: StampSpot.Spot?
    ) -> StampMark {
      guard let spot else { return mark }
      return StampMark(
        radius: mark.radius * spot.share,
        operators: Self.scaled(mark.operators, by: spot.share),
        acrossPage: spot.acrossPage,
        upPage: spot.upPage
      )
    }

    /// The drawing, made smaller about its own centre.
    private static func scaled(_ operators: String, by share: Double) -> String {
      guard share < 1 else { return operators }
      let factor = String(format: "%.4f", share)
      return "q \(factor) 0 0 \(factor) 0 0 cm\n\(operators)Q\n"
    }
  }

#endif
