// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The tracer's invariants: the outlines describe the bitmap exactly,
/// simplification keeps the shape, and a closed loop survives the pass
/// that a naive Douglas-Peucker would flatten to nothing.
@Suite
internal struct InkOutlineTests {
  /// A bitmap from rows of characters, `#` being ink.
  private static func bitmap(_ rows: [String]) -> InkOutline.Bitmap {
    let width = rows.first?.count ?? 0
    let ink = rows.flatMap { row in row.map { $0 == "#" } }
    guard
      let made = InkOutline.Bitmap(
        width: width, height: rows.count, ink: ink
      )
    else {
      preconditionFailure("malformed test bitmap")
    }
    return made
  }

  @Test
  internal func aSolidRectangleTracesToItsFourCorners() {
    // Nine pixels, twelve boundary edges, one loop - and once the
    // collinear steps are dropped, four corners and the closing
    // vertex.
    let square = Self.bitmap(["###", "###", "###"])

    let outlines = InkOutline.simplified(
      InkOutline.trace(square), tolerance: 0.5
    )

    #expect(outlines.count == 1)
    #expect(outlines.first?.count == 5)
    #expect(outlines.first?.first == outlines.first?.last)
  }

  @Test
  internal func aRingTracesAsTwoLoops() {
    // A hole is its own closed loop, wound against the outer one, so
    // a nonzero fill leaves it empty rather than painting over it.
    let ring = Self.bitmap(["#####", "#   #", "#   #", "#   #", "#####"])

    let outlines = InkOutline.trace(ring)

    #expect(outlines.count == 2)
    #expect(outlines.allSatisfy { $0.first == $0.last })
  }

  @Test
  internal func simplificationKeepsAClosedLoopsShape() {
    // The regression this guards: measuring deviation against the
    // segment from a loop's first vertex to its last measures against
    // a zero-length line, finds no deviation anywhere, and collapses
    // the shape. A rectangle must keep four corners.
    let bar = Self.bitmap([
      "##########",
      "##########",
      "##########",
    ])

    let outlines = InkOutline.simplified(
      InkOutline.trace(bar), tolerance: 0.8
    )

    #expect(outlines.count == 1)
    #expect(outlines.first?.count == 5)
    let horizontals = outlines.first?.map(\.across) ?? []
    let verticals = outlines.first?.map(\.down) ?? []
    #expect(horizontals.min() == 0)
    #expect(horizontals.max() == 10)
    #expect(verticals.min() == 0)
    #expect(verticals.max() == 3)
  }

  @Test
  internal func simplificationRemovesTheCollinearSteps() {
    // A long straight edge arrives as one vertex per pixel; what
    // survives is the corners.
    let line = Self.bitmap([String(repeating: "#", count: 60)])

    let traced = InkOutline.trace(line)
    let simplified = InkOutline.simplified(traced, tolerance: 0.5)

    #expect(traced.first?.count ?? 0 > 60)
    #expect(simplified.first?.count == 5)
  }

  @Test
  internal func operatorsFlipIntoPdfCoordinates() {
    // PDF measures up from the bottom left; the bitmap measures down
    // from the top left. A shape touching the bitmap's top row must
    // come out at the top of the box, not the bottom.
    let square = Self.bitmap(["##", "##"])

    let text = InkOutline.pdfOperators(
      InkOutline.simplified(InkOutline.trace(square), tolerance: 0.5),
      height: 2,
      decimals: 1
    )

    #expect(text.contains(" m\n"))
    #expect(text.hasSuffix("f\n"))
    #expect(text.contains("0.0 2.0"))
    #expect(text.contains("2.0 0.0"))
    #expect(!text.contains("-"))
  }

  @Test
  internal func anEmptyBitmapDrawsNothing() {
    let blank = Self.bitmap(["   ", "   "])

    let outlines = InkOutline.trace(blank)

    #expect(outlines.isEmpty)
    #expect(InkOutline.pdfOperators(outlines, height: 2, decimals: 1).isEmpty)
  }

  @Test
  internal func aBitmapWhoseSizeDisagreesWithItsPixelsIsRefused() {
    #expect(InkOutline.Bitmap(width: 3, height: 3, ink: [true, false]) == nil)
    #expect(InkOutline.Bitmap(width: 0, height: 0, ink: []) == nil)
  }
}
