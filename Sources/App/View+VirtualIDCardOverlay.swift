// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import SwiftUI

  /// How far an editable row may wrap.
  ///
  /// At file scope because a protocol extension cannot hold stored
  /// properties, and the two treatments below both need them.
  private enum LineLimits {
    static let field = 1...2
    static let menu = 1...3
  }

  /// Row treatments that grow with Dynamic Type.
  ///
  /// Form rows must grow with Dynamic Type instead of retaining the compact
  /// one-line text-field height. One shared treatment keeps every editable
  /// virtual-card value usable under the same accessibility settings.
  extension View {
    /// An editable virtual-card value that wraps rather than truncates.
    internal func virtualCardEditorField() -> some View {
      lineLimit(LineLimits.field)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A menu control label, which is allowed one line more than a field.
    internal func virtualCardMenuControl() -> some View {
      lineLimit(LineLimits.menu)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

#endif
