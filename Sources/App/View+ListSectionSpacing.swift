// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

extension View {
  /// Sets the spacing between list sections where the system offers it.
  ///
  /// A system without the modifier keeps its own section spacing, which is
  /// the spacing this value was chosen to replace rather than to enable.
  @ViewBuilder
  internal func listSections(spacing: CGFloat) -> some View {
    #if os(iOS)
      listSectionSpacing(spacing)
    #else
      self
    #endif
  }
}
