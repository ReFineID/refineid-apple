// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI

  /// Edits one complete virtual card/device snapshot and one fault plan.
  internal struct VirtualIDCardEditor: View {
    // MARK: Nested Types

    /// The unchanging labels of one PIN/PUK credential row.
    private struct CredentialFieldSpec {
      let title: String
      let identifier: String
      let valueLabel: String
      let attemptsLabel: String
    }

    // MARK: Static Computed Properties

    /// The scenarios a demonstration on this device class can offer.
    internal static var offeredScenarios: [VirtualIDCard.Scenario] {
      VirtualIDCard.Scenario.allCases.filter { scenario in
        DemoMode.offersNearField || !scenario.usesNearField
      }
    }

    private static let minimumAttempts = 0
    internal static let menuLineSpacing: CGFloat = 2

    /// The faults a demonstration on this device class can offer.
    internal static var offeredFaultPresets: [VirtualIDCard.FaultPreset] {
      VirtualIDCard.FaultPreset.allCases.filter { preset in
        DemoMode.offersNearField || !preset.usesNearField
      }
    }

    // MARK: SwiftUI Properties

    @State private var draft: VirtualIDCard.Snapshot
    @State private var scenario = VirtualIDCard.Scenario.factoryFreshNearField
    @State private var faultPreset = VirtualIDCard.FaultPreset.noFault

    // MARK: Properties

    internal let demoMode: DemoMode
    internal let close: () -> Void

    // MARK: Content Properties

    /// The scenario menu, held apart so the form's body stays
    /// within what the type checker will infer in one piece.
    @ViewBuilder private var scenarioSection: some View {
      Section(
        virtualCardLocalized("section.scenario", defaultValue: "Scenario")
      ) {
        scenarioMenu
      }
    }

    @ViewBuilder private var scenarioMenu: some View {
      Menu {
        scenarioOptions
      } label: {
        scenarioMenuLabel
      }
      .tint(.primary)
      .onValueChange(of: scenario) { selected in
        draft = Self.deviceScoped(selected.snapshot)
        faultPreset = .noFault
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("virtualCardScenario")
      .accessibilityLabel(
        Text(
          virtualCardLocalized(
            "scenario.accessibilityLabel",
            defaultValue: "Virtual card scenario")))
    }

    @ViewBuilder private var scenarioOptions: some View {
      ForEach(Self.offeredScenarios, id: \.self) { candidate in
        Button {
          scenario = candidate
        } label: {
          if scenario == candidate {
            Label(candidate.localizedName, systemImage: "checkmark")
          } else {
            Text(candidate.localizedName)
          }
        }
        .accessibilityIdentifier(
          "virtualCardScenarioOption.\(candidate.rawValue)")
      }
    }

    @ViewBuilder private var scenarioMenuLabel: some View {
      VStack(alignment: .leading, spacing: Self.menuLineSpacing) {
        Text(
          virtualCardLocalized(
            "scenario.preset",
            defaultValue: "Preset")
        )
        .foregroundStyle(.primary)
        Text(scenario.localizedName)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .virtualCardMenuControl()
    }

    internal var body: some View {
      NavigationStack {
        Form {
          scenarioSection
          VirtualIDCardConnectionSection(draft: $draft)
          VirtualIDCardIdentitySection(draft: $draft)
          VirtualIDCardActivationSection(draft: $draft)
          pin1Credentials
          pin2Credentials
          pukCredentials
          VirtualIDCardCertificatesSection(draft: $draft)
          VirtualIDCardDeviceSection(draft: $draft)
          VirtualIDCardFaultSection(faultPreset: $faultPreset)
        }
        .headerProminence(.increased)
        .navigationTitle(
          virtualCardLocalized("title", defaultValue: "Virtual ID Card")
        )
        .accessibilityIdentifier("virtualCardEditor")
        .toolbar {
          editorToolbar
        }
      }
    }

    @ViewBuilder private var pin1Credentials: some View {
      credentialSection(
        CredentialFieldSpec(
          title: virtualCardLocalized("credential.pin1", defaultValue: "PIN 1"),
          identifier: "virtualCardPIN1",
          valueLabel: virtualCardLocalized(
            "credential.pin1Value",
            defaultValue: "PIN 1 value"),
          attemptsLabel: virtualCardLocalized(
            "credential.pin1Attempts",
            defaultValue: "PIN 1 attempts")),
        value: $draft.card.pin1.value,
        attempts: attemptsBinding(\.pin1))
    }

    @ViewBuilder private var pin2Credentials: some View {
      credentialSection(
        CredentialFieldSpec(
          title: virtualCardLocalized("credential.pin2", defaultValue: "PIN 2"),
          identifier: "virtualCardPIN2",
          valueLabel: virtualCardLocalized(
            "credential.pin2Value",
            defaultValue: "PIN 2 value"),
          attemptsLabel: virtualCardLocalized(
            "credential.pin2Attempts",
            defaultValue: "PIN 2 attempts")),
        value: $draft.card.pin2.value,
        attempts: attemptsBinding(\.pin2))
    }

    @ViewBuilder private var pukCredentials: some View {
      credentialSection(
        CredentialFieldSpec(
          title: virtualCardLocalized("credential.puk", defaultValue: "PUK"),
          identifier: "virtualCardPUK",
          valueLabel: virtualCardLocalized(
            "credential.pukValue",
            defaultValue: "PUK value"),
          attemptsLabel: virtualCardLocalized(
            "credential.pukAttempts",
            defaultValue: "PUK attempts")),
        value: $draft.card.puk.value,
        attempts: attemptsBinding(\.puk))
    }

    @ToolbarContentBuilder private var editorToolbar: some ToolbarContent {
      ToolbarItem(placement: .cancellationAction) {
        Button(
          virtualCardLocalized("action.cancel", defaultValue: "Cancel")
        ) { close() }
        .accessibilityLabel(
          Text(
            virtualCardLocalized(
              "action.cancelAccessibilityLabel",
              defaultValue: "Cancel virtual card changes")))
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(
          virtualCardLocalized("action.apply", defaultValue: "Apply")
        ) {
          draft.faults = faultPreset.faults
          demoMode.replace(with: draft)
          close()
        }
        .accessibilityIdentifier("virtualCardApply")
        .accessibilityLabel(
          Text(
            virtualCardLocalized(
              "action.applyAccessibilityLabel",
              defaultValue: "Apply virtual card changes")))
      }
    }

    // MARK: Lifecycle

    internal init(demoMode: DemoMode, close: @escaping () -> Void) {
      self.demoMode = demoMode
      self.close = close
      let current = Self.deviceScoped(demoMode.state)
      _draft = State(initialValue: current)
      _scenario = State(
        initialValue: VirtualIDCard.Scenario.allCases.first { candidate in
          let scoped = Self.deviceScoped(candidate.snapshot)
          return scoped.card == current.card
            && scoped.device == current.device
        } ?? DemoMode.defaultScenario)
      _faultPreset = State(
        initialValue: VirtualIDCard.FaultPreset.allCases.first { preset in
          preset.faults == current.faults
        } ?? .noFault)
    }

    // MARK: Static Functions

    /// Clamps a snapshot to the transports this device class offers.
    private static func deviceScoped(
      _ snapshot: VirtualIDCard.Snapshot
    ) -> VirtualIDCard.Snapshot {
      guard !DemoMode.offersNearField else { return snapshot }
      var snapshot = snapshot
      snapshot.card.transport = .reader
      return snapshot
    }

    // MARK: Content Methods

    private func credentialSection(
      _ spec: CredentialFieldSpec,
      value: Binding<String>,
      attempts: Binding<Int>
    ) -> some View {
      Section(spec.title) {
        TextField(spec.valueLabel, text: value, axis: .vertical)
          .keyboardType(.numberPad)
          .virtualCardEditorField()
          .accessibilityIdentifier("\(spec.identifier)Value")
        Stepper(
          value: attempts,
          in: Self.minimumAttempts...Int(RetryCount.pristineAllowance)
        ) {
          LabeledContent(spec.attemptsLabel) {
            Text(String(attempts.wrappedValue))
          }
        }
        .accessibilityIdentifier("\(spec.identifier)Attempts")
        .accessibilityValue(
          Text(
            String.localizedStringWithFormat(
              virtualCardLocalized(
                "credential.attemptsRemaining",
                defaultValue: "%lld attempts remaining"),
              attempts.wrappedValue)))
      }
    }

    // MARK: Functions

    private func attemptsBinding(
      _ keyPath: WritableKeyPath<
        VirtualIDCard.CardState,
        VirtualIDCard.CredentialState
      >
    ) -> Binding<Int> {
      Binding(
        get: {
          Int(draft.card[keyPath: keyPath].attemptsRemaining)
        },
        set: { value in
          draft.card[keyPath: keyPath].attemptsRemaining = UInt8(value)
        })
    }

  }

#endif
