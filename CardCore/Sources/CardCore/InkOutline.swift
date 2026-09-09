// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Turns a bilevel image into closed outlines, and those into PDF path
/// operators.
///
/// The holder's signature comes off the card as a small bitmap, and a
/// bitmap pasted into a page is fixed at whatever resolution it
/// happened to have. Traced to outlines it is a drawing: it scales to
/// any size a reader zooms to, prints at the printer's resolution
/// rather than the card's, and carries no white box - a filled path
/// paints only where the ink was.
///
/// The trace is exact before it is simplified. Every boundary between
/// an ink pixel and a background pixel becomes one edge of a closed
/// loop, so the outlines describe the bitmap and nothing else; the
/// simplification that follows is the only lossy step, and its
/// tolerance is stated in pixels.
public enum InkOutline {
  /// One traced outline: a closed loop of vertices on the pixel grid.
  public typealias Outline = [Vertex]

  /// A corner of the pixel grid, in image coordinates with the origin
  /// at the top left - the order the bitmap arrives in.
  public struct Vertex: Hashable, Sendable {
    /// Distance from the left edge, in pixels.
    public let across: Double

    /// Distance from the top edge, in pixels.
    public let down: Double

    /// Places a vertex.
    public init(across: Double, down: Double) {
      self.across = across
      self.down = down
    }
  }

  /// A bilevel image: which pixels are ink, and how they are laid out.
  public struct Bitmap: Sendable {
    /// Pixels per row.
    public let width: Int

    /// Rows.
    public let height: Int

    /// Row-major, one entry per pixel, true where there is ink.
    public let ink: [Bool]

    /// Composes a bitmap, refusing one whose size and content
    /// disagree.
    public init?(width: Int, height: Int, ink: [Bool]) {
      guard width > 0, height > 0, ink.count == width * height else {
        return nil
      }
      self.width = width
      self.height = height
      self.ink = ink
    }

    /// Whether the pixel at these coordinates is ink; anything off the
    /// bitmap is background, which is what closes the outlines at the
    /// edges.
    internal func isInk(column: Int, row: Int) -> Bool {
      guard column >= 0, column < width, row >= 0, row < height else {
        return false
      }
      return ink[row * width + column]
    }
  }

  /// Fewest vertices an open chain can have and still hold one that
  /// simplification might drop.
  private static let shortestSimplifiableChain = 2

  /// Fewest vertices a closed loop can have and still enclose an area.
  private static let shortestClosedLoop = 3

  /// The outlines of every ink region, holes included.
  ///
  /// Each loop is closed: its last vertex is its first. A hole comes
  /// back as its own loop wound the other way, which is what lets a
  /// nonzero fill leave it empty.
  public static func trace(_ bitmap: Bitmap) -> [Outline] {
    var edges = Self.boundaryEdges(of: bitmap)
    var outlines: [Outline] = []
    while let start = edges.keys.first {
      guard let loop = Self.followLoop(from: start, edges: &edges) else {
        continue
      }
      outlines.append(loop)
    }
    return outlines
  }

  /// The same outlines with their needless vertices removed.
  ///
  /// A traced loop steps around every pixel corner, so a straight
  /// stroke arrives as hundreds of collinear points. `tolerance` is
  /// the furthest, in pixels, a dropped vertex may sit from the line
  /// that replaces it.
  public static func simplified(
    _ outlines: [Outline],
    tolerance: Double
  ) -> [Outline] {
    outlines.map { Self.simplifyClosed($0, tolerance: tolerance) }
      .filter { $0.count > Self.shortestClosedLoop }
  }

  /// PDF path operators filling the outlines, in a box `height` tall.
  ///
  /// PDF puts its origin at the bottom left and the bitmap puts its
  /// own at the top left, so every vertex is flipped on the way out.
  /// The result is a fill, not a stroke: the outlines already describe
  /// the shape of the ink, and stroking them would draw its edge
  /// twice.
  public static func pdfOperators(
    _ outlines: [Outline],
    height: Double,
    decimals: Int
  ) -> String {
    var text = ""
    for outline in outlines {
      guard let first = outline.first else { continue }
      text += Self.coordinates(first, height: height, decimals: decimals) + " m\n"
      for vertex in outline.dropFirst() {
        text += Self.coordinates(vertex, height: height, decimals: decimals) + " l\n"
      }
      text += "h\n"
    }
    return text.isEmpty ? "" : text + "f\n"
  }

  /// One vertex, flipped and rounded.
  private static func coordinates(
    _ vertex: Vertex,
    height: Double,
    decimals: Int
  ) -> String {
    String(format: "%.\(decimals)f %.\(decimals)f", vertex.across, height - vertex.down)
  }

  /// Every ink/background boundary as a directed edge.
  ///
  /// The four edges of an ink pixel are walked in one rotational
  /// order, so the loops they form come out consistently wound: an
  /// outer boundary one way, a hole the other.
  private static func boundaryEdges(
    of bitmap: Bitmap
  ) -> [Vertex: [Vertex]] {
    var edges: [Vertex: [Vertex]] = [:]
    for row in 0..<bitmap.height {
      for column in 0..<bitmap.width where bitmap.isInk(column: column, row: row) {
        let left = Double(column)
        let right = Double(column + 1)
        let top = Double(row)
        let bottom = Double(row + 1)
        if !bitmap.isInk(column: column, row: row - 1) {
          edges[Vertex(across: left, down: top), default: []]
            .append(Vertex(across: right, down: top))
        }
        if !bitmap.isInk(column: column + 1, row: row) {
          edges[Vertex(across: right, down: top), default: []]
            .append(Vertex(across: right, down: bottom))
        }
        if !bitmap.isInk(column: column, row: row + 1) {
          edges[Vertex(across: right, down: bottom), default: []]
            .append(Vertex(across: left, down: bottom))
        }
        if !bitmap.isInk(column: column - 1, row: row) {
          edges[Vertex(across: left, down: bottom), default: []]
            .append(Vertex(across: left, down: top))
        }
      }
    }
    return edges
  }

  /// Walks edges from a starting vertex until the loop closes,
  /// consuming what it walks.
  private static func followLoop(
    from start: Vertex,
    edges: inout [Vertex: [Vertex]]
  ) -> Outline? {
    var loop: Outline = [start]
    var current = start
    while var candidates = edges[current] {
      guard let next = candidates.popLast() else {
        edges.removeValue(forKey: current)
        break
      }
      if candidates.isEmpty {
        edges.removeValue(forKey: current)
      } else {
        edges[current] = candidates
      }
      loop.append(next)
      current = next
      if next == start { return loop }
    }
    return nil
  }

  /// Douglas-Peucker over a closed loop.
  ///
  /// A closed loop begins and ends at the same vertex, so measuring
  /// every deviation against that zero-length baseline would find no
  /// deviation at all and collapse the shape to nothing. The loop is
  /// cut at the vertex furthest from its start and the two open
  /// chains are simplified instead.
  private static func simplifyClosed(
    _ loop: Outline,
    tolerance: Double
  ) -> Outline {
    var points = loop
    if points.count > 1, points.first == points.last {
      points.removeLast()
    }
    guard points.count > Self.shortestClosedLoop else { return loop }
    // Start the loop at a corner. The trace begins wherever the edge
    // table was first entered, and a start that falls mid-edge is an
    // endpoint no simplification may drop - leaving one vertex in the
    // middle of a straight run. The topmost-then-leftmost vertex is
    // always a corner of the outline, and choosing it also makes the
    // result the same whatever order the edges were walked in.
    let corner =
      points.indices.min { left, right in
        (points[left].down, points[left].across)
          < (points[right].down, points[right].across)
      } ?? 0
    points = Array(points[corner...] + points[..<corner])
    guard let origin = points.first else { return loop }
    let furthest =
      points.indices.max { left, right in
        Self.squaredDistance(points[left], origin)
          < Self.squaredDistance(points[right], origin)
      } ?? 0
    let head = Self.simplifyOpen(
      Array(points[...furthest]), tolerance: tolerance
    )
    let tail = Self.simplifyOpen(
      Array(points[furthest...]) + [origin], tolerance: tolerance
    )
    return head.dropLast() + tail
  }

  /// Douglas-Peucker over an open chain.
  private static func simplifyOpen(
    _ points: Outline,
    tolerance: Double
  ) -> Outline {
    guard points.count > Self.shortestSimplifiableChain,
      let first = points.first, let last = points.last
    else {
      return points
    }
    var worst = 0.0
    var worstIndex = 0
    for index in 1..<(points.count - 1) {
      let distance = Self.distance(points[index], from: first, to: last)
      if distance > worst {
        worst = distance
        worstIndex = index
      }
    }
    guard worst > tolerance else { return [first, last] }
    let head = Self.simplifyOpen(
      Array(points[...worstIndex]), tolerance: tolerance
    )
    let tail = Self.simplifyOpen(
      Array(points[worstIndex...]), tolerance: tolerance
    )
    return head.dropLast() + tail
  }

  /// Perpendicular distance from a point to a segment's line; the
  /// distance to the shared endpoint when the segment has no length.
  private static func distance(
    _ point: Vertex,
    from first: Vertex,
    to last: Vertex
  ) -> Double {
    let runX = last.across - first.across
    let runY = last.down - first.down
    let length = (runX * runX + runY * runY).squareRoot()
    guard length > 0 else {
      return Self.squaredDistance(point, first).squareRoot()
    }
    let cross =
      runY * (point.across - first.across)
      - runX * (point.down - first.down)
    return abs(cross) / length
  }

  /// Squared distance between two vertices.
  private static func squaredDistance(_ one: Vertex, _ other: Vertex) -> Double {
    let apartX = one.across - other.across
    let apartY = one.down - other.down
    return apartX * apartX + apartY * apartY
  }
}
