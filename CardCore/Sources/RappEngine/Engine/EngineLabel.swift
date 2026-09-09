// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Bounds a free-text label the protocol carries.
internal enum EngineLabel {
  /// The longest label the wire accepts, in bytes.
  internal static let maximumBytes = 4_096

  /// Whether a label is present and within bounds.
  ///
  /// A label that is empty once trimmed carries no information, so it is
  /// refused rather than sent as blank text.
  internal static func isValid(_ value: String) -> Bool {
    !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && value.utf8.count <= maximumBytes
  }
}
