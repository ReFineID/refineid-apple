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

    @ViewBuilder private var faultMenu: some View {
      Picker(
        virtualCardLocalized(
          "fault.picker",
          defaultValue: "Fault"),
        selection: $faultPreset
      ) {
        ForEach(VirtualIDCardEditor.offeredFaultPresets, id: \.self) { preset in
          Text(preset.localizedName)
            .tag(preset)
            .accessibilityIdentifier(
              "virtualCardFaultOption.\(preset.rawValue)")
        }
      }
      .pickerStyle(.menu)
      .tint(.primary)
      .virtualCardMenuControl()
      .accessibilityIdentifier("virtualCardFault")
    }
  }

#endif
