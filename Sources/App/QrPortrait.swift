// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import Foundation

  /// Turns a valid QR matrix toward the portrait while preserving every
  /// structural module and a measured correction margin.
  internal enum QrPortrait {
    /// Everything the PDF renderer needs to keep centres readable and
    /// density portrait-shaped.
    internal struct Artwork: Equatable, Sendable {
      internal let original: [Bool]
      internal let treated: [Bool]
      internal let functionModules: [Bool]
      internal let darkness: [Double]
      internal let side: Int
      internal let flippedCount: Int
      internal let fieldSide: Int
      internal let fieldDarkness: [Double]
    }

    /// A possible data-module change, ranked by portrait certainty.
    private struct Candidate {
      let index: Int
      let target: Bool
      let confidence: Double
    }

    /// Dot size carries the portrait without spending QR data modules.
    ///
    /// Error correction stays available for handwriting, print, focus and
    /// perspective damage.
    internal static let productionFlipShare = 0.0

    /// A complete share, used to validate treatment requests.
    private static let fullShare = 1.0

    /// QR version-to-side conversion constants.
    private static let baseModuleSide = 17
    private static let modulesPerVersion = 4

    /// Fixed structural coordinates and edge insets.
    private static let finderAndFormatCoordinate = 8
    private static let finderFarInset = 8
    private static let timingCoordinate = 6

    /// Version-information geometry, present from version seven.
    private static let firstVersionCarryingInformation = 7
    private static let versionInformationNearEnd = 5
    private static let versionInformationFarStartInset = 11
    private static let versionInformationFarEndInset = 9

    /// Alignment-pattern geometry and spacing formula constants.
    private static let versionsPerAlignmentPattern = 7
    private static let baseAlignmentPatternCount = 2
    private static let exceptionalAlignmentVersion = 32
    private static let exceptionalAlignmentStep = 26
    private static let alignmentEdgeInset = 7
    private static let alignmentRadius = 2
    private static let double = 2
    private static let roundingAddition = 1

    /// Pulls the measured production share of data modules toward the
    /// portrait.
    internal static func artwork(
      qr qrCode: QrCode.Modules,
      portrait: PortraitHalftone.Map
    ) -> Artwork? {
      Self.artwork(
        qr: qrCode,
        portrait: portrait,
        flipShare: Self.productionFlipShare
      )
    }

    /// Pulls a specified share of data modules toward the portrait.
    internal static func artwork(
      qr qrCode: QrCode.Modules,
      portrait: PortraitHalftone.Map,
      flipShare: Double
    ) -> Artwork? {
      guard
        qrCode.side == portrait.side,
        qrCode.dark.count == portrait.darkness.count,
        flipShare >= 0,
        flipShare <= Self.fullShare
      else {
        return nil
      }
      let functions = Self.functionMask(side: qrCode.side)
      var candidates = [Candidate]()
      var dataModuleCount = 0
      for index in qrCode.dark.indices where !functions[index] {
        dataModuleCount += 1
        let target = portrait.darkness[index] >= PortraitHalftone.threshold
        guard target != qrCode.dark[index] else { continue }
        candidates.append(
          Candidate(
            index: index,
            target: target,
            confidence: abs(
              portrait.darkness[index] - PortraitHalftone.threshold
            )
          )
        )
      }
      candidates.sort { left, right in
        if left.confidence == right.confidence { return left.index < right.index }
        return left.confidence > right.confidence
      }
      let count = min(
        candidates.count,
        Int((Double(dataModuleCount) * flipShare).rounded())
      )
      var treated = qrCode.dark
      for candidate in candidates.prefix(count) {
        treated[candidate.index] = candidate.target
      }
      return Artwork(
        original: qrCode.dark,
        treated: treated,
        functionModules: functions,
        darkness: portrait.darkness,
        side: qrCode.side,
        flippedCount: count,
        fieldSide: portrait.fieldSide,
        fieldDarkness: portrait.fieldDarkness
      )
    }

    /// Finder, timing, format, version and alignment modules.
    private static func functionMask(side: Int) -> [Bool] {
      var mask = [Bool](repeating: false, count: side * side)
      Self.markRectangle(
        columns: 0...Self.finderAndFormatCoordinate,
        rows: 0...Self.finderAndFormatCoordinate,
        in: &mask,
        side: side
      )
      Self.markFarFinders(in: &mask, side: side)
      for coordinate in 0..<side {
        Self.mark(coordinate, Self.timingCoordinate, in: &mask, side: side)
        Self.mark(Self.timingCoordinate, coordinate, in: &mask, side: side)
        // Conservatively preserve the complete format axes. The cells
        // beyond the actual words are data, but only reduce visual budget.
        Self.mark(
          coordinate,
          Self.finderAndFormatCoordinate,
          in: &mask,
          side: side
        )
        Self.mark(
          Self.finderAndFormatCoordinate,
          coordinate,
          in: &mask,
          side: side
        )
      }
      let version = (side - Self.baseModuleSide) / Self.modulesPerVersion
      Self.markVersionInformation(version: version, in: &mask, side: side)
      Self.markAlignmentPatterns(version: version, in: &mask, side: side)
      return mask
    }

    /// Marks the two finder regions against the far edges.
    private static func markFarFinders(in mask: inout [Bool], side: Int) {
      Self.markRectangle(
        columns: (side - Self.finderFarInset)...(side - 1),
        rows: 0...Self.finderAndFormatCoordinate,
        in: &mask,
        side: side
      )
      Self.markRectangle(
        columns: 0...Self.finderAndFormatCoordinate,
        rows: (side - Self.finderFarInset)...(side - 1),
        in: &mask,
        side: side
      )
    }

    /// Marks version-information blocks when the QR version carries them.
    private static func markVersionInformation(
      version: Int,
      in mask: inout [Bool],
      side: Int
    ) {
      guard version >= Self.firstVersionCarryingInformation else { return }
      Self.markRectangle(
        columns: (side - Self.versionInformationFarStartInset)...(side
          - Self.versionInformationFarEndInset),
        rows: 0...Self.versionInformationNearEnd,
        in: &mask,
        side: side
      )
      Self.markRectangle(
        columns: 0...Self.versionInformationNearEnd,
        rows: (side - Self.versionInformationFarStartInset)...(side
          - Self.versionInformationFarEndInset),
        in: &mask,
        side: side
      )
    }

    /// Marks every alignment pattern that does not overlap a finder.
    private static func markAlignmentPatterns(
      version: Int,
      in mask: inout [Bool],
      side: Int
    ) {
      let centres = Self.alignmentCentres(version: version, side: side)
      for centreRow in centres {
        for centreColumn in centres {
          let overlapsFinder =
            (centreColumn == Self.timingCoordinate
              && (centreRow == Self.timingCoordinate
                || centreRow == side - Self.alignmentEdgeInset))
            || (centreColumn == side - Self.alignmentEdgeInset
              && centreRow == Self.timingCoordinate)
          guard !overlapsFinder else { continue }
          Self.markRectangle(
            columns: (centreColumn - Self.alignmentRadius)...(centreColumn + Self.alignmentRadius),
            rows: (centreRow - Self.alignmentRadius)...(centreRow + Self.alignmentRadius),
            in: &mask,
            side: side
          )
        }
      }
    }

    /// Alignment centres for one QR version.
    private static func alignmentCentres(version: Int, side: Int) -> [Int] {
      let count =
        version / Self.versionsPerAlignmentPattern
        + Self.baseAlignmentPatternCount
      guard count > 1 else { return [] }
      let step =
        version == Self.exceptionalAlignmentVersion
        ? Self.exceptionalAlignmentStep
        : ((version * Self.modulesPerVersion + count * Self.double
          + Self.roundingAddition) / (count * Self.double - Self.double))
          * Self.double
      var centres = [Self.timingCoordinate]
      for index in 1..<count {
        centres.append(
          side - Self.alignmentEdgeInset - (count - 1 - index) * step
        )
      }
      return centres
    }

    /// Marks one rectangle, clipped to the matrix.
    private static func markRectangle(
      columns: ClosedRange<Int>,
      rows: ClosedRange<Int>,
      in mask: inout [Bool],
      side: Int
    ) {
      for row in rows {
        for column in columns {
          Self.mark(column, row, in: &mask, side: side)
        }
      }
    }

    /// Marks one matrix coordinate when it is in bounds.
    private static func mark(
      _ column: Int,
      _ row: Int,
      in mask: inout [Bool],
      side: Int
    ) {
      guard column >= 0, row >= 0, column < side, row < side else { return }
      mask[row * side + column] = true
    }
  }

#endif
