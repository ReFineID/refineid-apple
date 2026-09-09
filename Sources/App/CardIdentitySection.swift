// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

/// The finished state: who the stored card says they are.
///
/// The same row a connected reader shows, read from the stored prime
/// rather than from the token: a registered card's token has to be minted
/// before the keychain can answer for it, and minting one over near field
/// opens a scan sheet on a screen nobody asked to scan from.
internal struct CardIdentitySection: View {
  /// The minimum comfortable tap target.
  private static let tapTargetSide: CGFloat = 44

  /// Minimum gap between the holder name and the forget control.
  private static let forgetButtonGap: CGFloat = 4

  /// Spacing between the person label and the holder name.
  private static let identityDetailsSpacing: CGFloat = 4

  /// The complete holder name read from the primed identity certificate.
  internal let holder: String

  /// Removes the device-local identity after the parent confirms the action.
  internal let forget: () -> Void

  internal var body: some View {
    Section {
      HStack {
        VStack(alignment: .leading, spacing: Self.identityDetailsSpacing) {
          PersonRowLabel(configured: true)
          Text(holder)
            .font(.body)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        .accessibilityIdentifier("identityStatus")
        Spacer(minLength: Self.forgetButtonGap)
        // The forget action lives on the row it removes, pinned to
        // the trailing edge and centered in the row's height; the
        // confirmation dialog still stands in front of it.
        Button(role: .destructive, action: forget) {
          Image(systemName: "minus.circle")
            .font(.title3)
            .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
        .frame(width: Self.tapTargetSide, height: Self.tapTargetSide)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("Forget identity"))
        .accessibilityIdentifier("forgetCardIdentityButton")
      }
    } header: {
      Text("Identity")
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
    }
  }
}
