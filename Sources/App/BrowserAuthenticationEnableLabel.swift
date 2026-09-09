// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.
// SPDX-License-Identifier: EUPL-1.2

import SwiftUI

/// The single presentation of the browser-authentication enable action.
///
/// Both configured and first-use card paths use this view so their icon,
/// foreground treatment, and accessibility label cannot diverge.
internal struct BrowserAuthenticationEnableLabel: View {
  private enum Geometry {
    static let verticalPadding: CGFloat = 8
  }

  internal var body: some View {
    Label("Enable", systemImage: "person.badge.key.fill")
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, Geometry.verticalPadding)
  }
}
