// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

#if os(macOS)

  /// How a retry counter is shown: the number against a full card, a
  /// colour band, and a marker so the band never rests on colour alone.
  ///
  /// The bands are this app's own rule made visible. Full is green;
  /// below full is orange, because something has already gone wrong
  /// once; one or two is red, the range it refuses to work in; and
  /// zero is blue, because blocked is not a warning but an instruction
  /// - the PUK undoes it.
  extension CardManagementView {
    // MARK: Nested Types

    private enum AttemptsLayout {
      static let rowSymbolSpacing: CGFloat = 4
      static let attemptsSpacing: CGFloat = 14
      static let barHorizontalPadding: CGFloat = 16
      static let barVerticalPadding: CGFloat = 6
      static let barLineSpacing: CGFloat = 4
    }

    // MARK: Static Functions

    /// The marker beside each count, so the band is never carried by
    /// colour alone.
    private static func attemptsSymbol(_ outcome: RetryProbeOutcome?) -> String {
      switch outcome {
      case .remaining(let count):
        if count.isBlocked {
          "arrow.counterclockwise.circle.fill"
        } else if count.attemptsRemaining < RetryFloor.minimumAttemptsToProceed {
          "xmark.octagon.fill"
        } else if count.attemptsRemaining < RetryCount.pristineAllowance {
          "exclamationmark.triangle.fill"
        } else {
          "checkmark.circle.fill"
        }

      case .verified:
        "checkmark.circle.fill"

      case .locked:
        "arrow.counterclockwise.circle.fill"

      case .invalidated:
        "xmark.octagon.fill"

      case .noInformation, .other, .none:
        "questionmark.circle"
      }
    }

    /// What VoiceOver says for one reading.
    private static func attemptsSpoken(_ outcome: RetryProbeOutcome?) -> String {
      switch outcome {
      case .remaining(let count):
        if count.isBlocked {
          String(localized: "blocked - unblock with the PUK")
        } else if count.attemptsRemaining >= RetryFloor.minimumAttemptsToProceed {
          String(localized: "\(count.attemptsRemaining) attempts remaining")
        } else {
          String(localized: "\(count.attemptsRemaining) attempts remaining - low")
        }

      case .verified:
        String(localized: "verified this session")

      case .locked:
        String(localized: "blocked - unblock with the PUK")

      case .invalidated:
        String(localized: "invalidated - contact the issuer")

      case .noInformation, .other:
        String(localized: "state unknown")

      case .none:
        String(localized: "no card present")
      }
    }

    /// One probe outcome as a short cell, counted against a full card.
    private static func attemptsText(_ outcome: RetryProbeOutcome?) -> String {
      switch outcome {
      case .remaining(let count):
        "\(count.attemptsRemaining)/\(RetryCount.pristineAllowance)"

      case .verified:
        String(localized: "verified")

      case .locked:
        String(localized: "blocked")

      case .invalidated:
        String(localized: "invalidated")

      case .noInformation, .other:
        String(localized: "unknown")

      case .none:
        String(localized: "no card")
      }
    }

    /// Full is green, short of full is orange, refused is red, and
    /// blocked is blue - blocked being the one state that is not a
    /// warning but an instruction: the PUK undoes it.
    private static func attemptsColor(_ outcome: RetryProbeOutcome?) -> Color {
      switch outcome {
      case .remaining(let count):
        if count.isBlocked {
          .blue
        } else if count.attemptsRemaining < RetryFloor.minimumAttemptsToProceed {
          .red
        } else if count.attemptsRemaining < RetryCount.pristineAllowance {
          .orange
        } else {
          .green
        }

      case .verified:
        .green

      case .locked:
        .blue

      case .invalidated:
        .red

      case .noInformation, .other, .none:
        .secondary
      }
    }

    // MARK: Functions

    /// The counters, pinned along the foot of the window.
    @ViewBuilder
    internal func attemptsBar(model: CardManagementModel) -> some View {
      VStack(alignment: .leading, spacing: AttemptsLayout.barLineSpacing) {
        HStack(spacing: AttemptsLayout.attemptsSpacing) {
          Text("Attempts left:")
            .foregroundStyle(.secondary)
          attemptsEntry("PIN 1", model.report?.pin1)
          attemptsEntry("PIN 2", model.report?.pin2)
          attemptsEntry("PUK", model.report?.puk)
          Spacer()
        }
      }
      .font(.footnote)
      .padding(.horizontal, AttemptsLayout.barHorizontalPadding)
      .padding(.vertical, AttemptsLayout.barVerticalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.bar)
    }

    /// One credential's reading.
    ///
    /// A symbol appears only when the count is not healthy, so the
    /// line stays quiet while everything is fine and still never
    /// relies on colour alone when it is not.
    @ViewBuilder
    internal func attemptsEntry(
      _ name: String,
      _ outcome: RetryProbeOutcome?
    ) -> some View {
      HStack(spacing: AttemptsLayout.rowSymbolSpacing) {
        Text("\(name) \(Self.attemptsText(outcome))")
          .monospacedDigit()
        Image(systemName: Self.attemptsSymbol(outcome))
      }
      .foregroundStyle(Self.attemptsColor(outcome))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(name)
      .accessibilityValue(Self.attemptsSpoken(outcome))
    }
  }

#endif
