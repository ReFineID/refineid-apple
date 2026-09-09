// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import SwiftUI

  internal struct RemoteDeviceRow: View {
    private enum Layout {
      static let rowSpacing: CGFloat = 8
      static let textVerticalSpacing: CGFloat = 2
      static let titleSpacing: CGFloat = 6
      static let statusBadgeSpacing: CGFloat = 4
      static let statusIndicatorSize: CGFloat = 6
      static let badgeTrailingPadding: CGFloat = 4
    }

    internal let name: String
    internal let modelName: String?
    internal let isOnline: Bool
    internal let isConnected: Bool
    internal let onDelete: () -> Void

    internal var body: some View {
      HStack(spacing: Layout.rowSpacing) {
        deviceInfo
        Spacer()
        statusBadge(isOnline: isOnline, isConnected: isConnected)
          .padding(.trailing, Layout.badgeTrailingPadding)
        actionButtons
      }
      .contextMenu {
        contextMenuButtons
      }
    }

    private var deviceInfo: some View {
      VStack(alignment: .leading, spacing: Layout.textVerticalSpacing) {
        Text(titleText)
          .font(.body.weight(.medium))
      }
    }

    private var titleText: String {
      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let rawModel = (modelName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedModel = RappDeviceIdentity.friendlyMarketingName(from: rawModel) ?? rawModel

      let isRawHardwareIdentifier =
        rawModel.range(of: #"^[A-Za-z]+[0-9]+,[0-9]+$"#, options: .regularExpression) != nil
        && RappDeviceIdentity.friendlyMarketingName(from: rawModel) == nil

      let effectiveModel = isRawHardwareIdentifier ? "" : resolvedModel

      let lowerName = trimmedName.lowercased()
      let isNetworkHostname =
        (lowerName.contains(".") && !lowerName.hasSuffix(".local"))
        || lowerName.contains(":")
        || lowerName == "localhost"

      let isGenericSubname =
        lowerName == "iphone"
        || lowerName == "ipad"
        || lowerName == "ipod"
        || lowerName == "apple device"
        || lowerName == "device"

      if !effectiveModel.isEmpty,
        !isNetworkHostname,
        !isGenericSubname,
        trimmedName.caseInsensitiveCompare(effectiveModel) != .orderedSame
      {
        return "\(effectiveModel) — \(trimmedName)"
      }
      if !effectiveModel.isEmpty {
        return effectiveModel
      }
      if !trimmedName.isEmpty, !isNetworkHostname {
        return trimmedName
      }
      return String(localized: "Remote device")
    }

    private var actionButtons: some View {
      Button {
        onDelete()
      } label: {
        Image(systemName: "trash")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityLabel(Text("Poista laite"))
      }
      .buttonStyle(.borderless)
      .help("Poista laite")
    }

    private var contextMenuButtons: some View {
      Button("Poista laite", role: .destructive) {
        onDelete()
      }
    }

    @ViewBuilder
    private func statusBadge(isOnline: Bool, isConnected: Bool) -> some View {
      if isConnected {
        HStack(spacing: Layout.statusBadgeSpacing) {
          Circle()
            .fill(Color.green)
            .frame(width: Layout.statusIndicatorSize, height: Layout.statusIndicatorSize)
          Text("Yhdistetty")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        }
      } else if isOnline {
        HStack(spacing: Layout.statusBadgeSpacing) {
          Circle()
            .fill(Color.green)
            .frame(width: Layout.statusIndicatorSize, height: Layout.statusIndicatorSize)
          Text("Linjoilla")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.green)
        }
      } else {
        Text(String(localized: "Offline"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

#endif
