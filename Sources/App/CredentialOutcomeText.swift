// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

/// A status message with one consistent visual and accessibility hierarchy.
internal struct CredentialOutcomeText: View {
  private enum Layout {
    static let twoLineCount = 2
    static let spacing = 4.0
  }

  internal enum Tone {
    case failure
    case notice
    case success
  }

  internal let message: String
  internal let tone: Tone

  internal var body: some View {
    switch tone {
    case .failure:
      emphasized(color: .red)

    case .notice:
      emphasized(color: .orange)

    case .success:
      Text(message)
        .foregroundStyle(.green)
        .bold()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .textSelection(.enabled)
    }
  }

  @ViewBuilder
  private func emphasized(color: Color) -> some View {
    let lines = message.split(
      separator: "\n",
      maxSplits: 1,
      omittingEmptySubsequences: false)

    Group {
      if lines.count == Layout.twoLineCount {
        VStack(spacing: Layout.spacing) {
          Text(String(lines[0]))
            .fontWeight(.semibold)
          Text(String(lines[1]))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
      } else {
        Text(message)
      }
    }
    .foregroundStyle(color)
    .accessibilityElement(children: .combine)
    .textSelection(.enabled)
  }
}
