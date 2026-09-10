// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI

  /// The virtual card activation generation, entry, and factory-state toggles.
  internal struct VirtualIDCardActivationSection: View {
    @Binding internal var draft: VirtualIDCard.Snapshot

    internal var body: some View {
      Section(
        virtualCardLocalized("section.activation", defaultValue: "Activation")
      ) {
        activationGenerationPicker
        activationEntryField
        activationFactoryToggles
      }
    }

    @ViewBuilder private var activationGenerationPicker: some View {
      Picker(
        virtualCardLocalized(
          "activation.generation",
          defaultValue: "Generation"),
        selection: $draft.card.generation
      ) {
        ForEach(VirtualIDCard.Generation.allCases, id: \.self) { generation in
          Text(generation.localizedName).tag(generation)
        }
      }
      .pickerStyle(.menu)
      .tint(.primary)
      .virtualCardMenuControl()
    }

    @ViewBuilder private var activationEntryField: some View {
      TextField(
        virtualCardLocalized(
          "activation.pin",
          defaultValue: "Activation PIN"),
        text: $draft.card.activationEntry,
        axis: .vertical
      )
      .keyboardType(.numberPad)
      .virtualCardEditorField()
      .accessibilityIdentifier("virtualCardActivationEntry")
    }

    @ViewBuilder private var activationFactoryToggles: some View {
      Toggle(
        virtualCardLocalized(
          "activation.pin1Factory",
          defaultValue: "PIN 1 is in factory state"),
        isOn: $draft.card.pin1.isFactoryValue
      )
      .accessibilityIdentifier("virtualCardPIN1Factory")
      Toggle(
        virtualCardLocalized(
          "activation.pin2Factory",
          defaultValue: "PIN 2 is in factory state"),
        isOn: $draft.card.pin2.isFactoryValue
      )
      .accessibilityIdentifier("virtualCardPIN2Factory")
    }
  }

#endif
