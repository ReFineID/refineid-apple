// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import AppKit
  import Foundation
  import PDFKit

  /// Finds somewhere on the last page the mark can sit without
  /// covering anything.
  ///
  /// The page is rendered and looked at, rather than its content
  /// streams read. A stream says what is drawn but not where the ink
  /// lands - text needs font metrics, an image needs its transform,
  /// and a form XObject needs all of it again one level down. A
  /// picture of the page answers directly, and it answers for
  /// annotations too, so a mark left by an earlier signer counts as
  /// occupied without being treated as a special case.
  internal enum StampSpot {
    /// Somewhere the mark fits, and how large it may be there.
    internal struct Spot {
      /// How far across the page the centre sits.
      internal let acrossPage: Double

      /// How far up the page it sits.
      internal let upPage: Double

      /// What the mark must be multiplied by to fit here, where one
      /// is its full size.
      internal let share: Double
    }

    /// Pixels per point when the page is rendered.
    ///
    /// Coarse on purpose: this looks for empty regions, and does not
    /// read the page.
    private static let renderScale = 1.0

    /// How far the search moves between candidate positions.
    private static let searchStep = 6.0

    /// Clear space demanded around the mark.
    private static let clearance = 4.0

    /// How far from white a pixel may be and still count as blank,
    /// so that a faint rule or a page's own texture does not.
    private static let blankLevel: UInt8 = 250

    /// How small the mark may be shrunk to rather than move, as a
    /// share of its full size.
    ///
    /// It carries a name and an identifier, and below this they stop
    /// being readable on paper - a mark nobody can read is worse than
    /// one sitting further from the corner.
    private static let smallestShare = 0.6

    /// The full size, and how much smaller each attempt is.
    private static let fullShare = 1.0
    private static let shrinkStep = 0.1
    private static let shrinkAttempts = 4

    /// Where a mark reaching `reach` from its centre fits on the last
    /// page, in that page's own coordinates, or nil when the page has
    /// no room for one at any size.
    ///
    /// Size is settled before place. A mark is looked for at its full
    /// size everywhere it could go, and only when the page has no room
    /// for one that big is a smaller one looked for - shrinking is the
    /// last thing given up, not the first, because a mark sitting a
    /// little further in is worth more than one small enough for the
    /// very corner.
    ///
    /// Within a size, the bottom-right corner is where a signature
    /// conventionally sits: the search starts there, steps left along
    /// the foot of the page, and rises a row to sweep right to left
    /// again only once a whole row is occupied.
    internal static func free(
      inLastPageOf document: Data,
      reach: Double
    ) -> Spot? {
      Self.free(
        inLastPageOf: document,
        reach: reach,
        minimumShare: Self.smallestShare
      )
    }

    /// The same search with a caller-imposed minimum scale.
    internal static func free(
      inLastPageOf document: Data,
      reach: Double,
      minimumShare: Double
    ) -> Spot? {
      guard
        let pdf = PDFDocument(data: document),
        pdf.pageCount > 0,
        let page = pdf.page(at: pdf.pageCount - 1)
      else {
        return nil
      }
      let box = page.bounds(for: .mediaBox)
      let ink = Self.coverage(of: page, box: box)
      guard !ink.isEmpty else { return nil }
      let rows = max(Int(box.height / Self.searchStep), 1)
      let columns = max(Int(box.width / Self.searchStep), 1)
      let acceptedShare = min(max(minimumShare, Self.smallestShare), 1)
      for attempt in 0...Self.shrinkAttempts {
        let share = Self.fullShare - Double(attempt) * Self.shrinkStep
        guard share >= acceptedShare else { continue }
        // Each size keeps its own margin to the page's edge, so a
        // shrunken mark sits in the corner rather than floating where
        // a larger one would have.
        let room = reach * share + Self.clearance
        rowScan: for row in 0..<rows {
          for column in 0..<columns {
            let centre = (
              horizontal: box.maxX - room - Double(column) * Self.searchStep,
              vertical: box.minY + room + Double(row) * Self.searchStep
            )
            // Columns run left and rows run up, so once either passes
            // the page's edge nothing further along it can fit.
            guard centre.horizontal - room >= box.minX else { break }
            guard centre.vertical + room <= box.maxY else { break rowScan }
            guard Self.isBlank(around: centre, reach: room, ink: ink, box: box)
            else {
              continue
            }
            return Spot(
              acrossPage: centre.horizontal - box.minX,
              upPage: centre.vertical - box.minY,
              share: share
            )
          }
        }
      }
      return nil
    }

    /// The page as one byte of grey per point.
    private static func coverage(
      of page: PDFPage,
      box: CGRect
    ) -> [UInt8] {
      let width = Int(box.width * Self.renderScale)
      let height = Int(box.height * Self.renderScale)
      guard width > 0, height > 0 else { return [] }
      var pixels = [UInt8](repeating: UInt8.max, count: width * height)
      guard
        let context = CGContext(
          data: &pixels,
          width: width,
          height: height,
          bitsPerComponent: UInt8.bitWidth,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else {
        return []
      }
      context.setFillColor(gray: 1, alpha: 1)
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      context.scaleBy(x: Self.renderScale, y: Self.renderScale)
      context.translateBy(x: -box.minX, y: -box.minY)
      page.draw(with: .mediaBox, to: context)
      return pixels
    }

    /// Whether every point around a centre is blank.
    private static func isBlank(
      around centre: (horizontal: Double, vertical: Double),
      reach: Double,
      ink: [UInt8],
      box: CGRect
    ) -> Bool {
      let width = Int(box.width * Self.renderScale)
      let height = Int(box.height * Self.renderScale)
      let left = Int((centre.horizontal - reach - box.minX) * Self.renderScale)
      let right = Int((centre.horizontal + reach - box.minX) * Self.renderScale)
      // The page's coordinates count up from its foot; the rendered
      // rows count down from its head. A bitmap context draws with its
      // origin at the bottom left but stores the top row first, so a
      // region read without turning it over is read from the opposite
      // end of the page - which is worse than no search at all, since
      // it calls the crowded foot empty and the empty head crowded.
      let bottom = Int((centre.vertical - reach - box.minY) * Self.renderScale)
      let top = Int((centre.vertical + reach - box.minY) * Self.renderScale)
      guard left >= 0, bottom >= 0, right < width, top < height else {
        return false
      }
      let firstRow = height - 1 - top
      let lastRow = height - 1 - bottom
      for row in firstRow...lastRow {
        let start = row * width
        for column in left...right where ink[start + column] < Self.blankLevel {
          return false
        }
      }
      return true
    }
  }

#endif
