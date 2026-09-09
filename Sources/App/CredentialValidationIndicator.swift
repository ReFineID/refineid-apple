// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import SwiftUI

/// One compact validation result shared by card credential forms.
internal struct CredentialValidationIndicator: View {
  // MARK: Properties

  internal let valid: Bool
  internal var entriesDiffer = false
  internal var unchanged = false
  internal var isEmpty = false

  // MARK: Computed Properties

  private var symbol: String {
    if valid { return "checkmark.circle.fill" }
    return hasWarning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"
  }

  private var color: Color {
    if valid { return .green }
    return hasWarning ? .orange : .red
  }

  private var hasWarning: Bool {
    entriesDiffer || unchanged
  }

  private var accessibilityDescription: String {
    if valid { return String(localized: "Valid entry") }
    if unchanged {
      return String(localized: "The new PIN must differ from the current PIN.")
    }
    if entriesDiffer { return String(localized: "The new entries differ.") }
    return String(localized: "Invalid entry")
  }

  // MARK: Content Properties

  internal var body: some View {
    Image(systemName: symbol)
      .foregroundStyle(color)
      .opacity(isEmpty ? 0 : 1)
      .accessibilityHidden(isEmpty)
      .accessibilityLabel(Text(accessibilityDescription))
  }
}
