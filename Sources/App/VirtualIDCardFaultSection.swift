// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) || os(macOS)

  import CardCore
  import SwiftUI

  /// The deterministic fault picker for the next virtual card operation.
  internal struct VirtualIDCardFaultSection: View {
    @Binding internal var faultPreset: VirtualIDCard.FaultPreset

    internal var body: some View {
      Section(
        virtualCardLocalized(
          "section.nextFault",
          defaultValue: "Next deterministic fault")
      ) {
        faultMenu
      }
    }

    @ViewBuilder private var faultOptions: some View {
      ForEach(VirtualIDCardEditor.offeredFaultPresets, id: \.self) { preset in
        Button {
          faultPreset = preset
        } label: {
          if faultPreset == preset {
            Label(preset.localizedName, systemImage: "checkmark")
          } else {
            Text(preset.localizedName)
          }
        }
        .accessibilityIdentifier(
          "virtualCardFaultOption.\(preset.rawValue)")
      }
    }

    @ViewBuilder private var faultMenuLabel: some View {
      VStack(alignment: .leading, spacing: VirtualIDCardEditor.menuLineSpacing) {
        Text(
          virtualCardLocalized(
            "fault.picker",
            defaultValue: "Fault")
        )
        .foregroundStyle(.primary)
        Text(faultPreset.localizedName)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .virtualCardMenuControl()
    }

    @ViewBuilder private var faultMenu: some View {
      Menu {
        faultOptions
      } label: {
        faultMenuLabel
      }
      .tint(.primary)
      .accessibilityIdentifier("virtualCardFault")
    }
  }

#endif
