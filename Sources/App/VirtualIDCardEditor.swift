// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI

  /// Edits one complete virtual card/device snapshot and one fault plan.
  internal struct VirtualIDCardEditor: View {
    // MARK: Static Computed Properties

    /// The scenarios a demonstration on this device class can offer.
    private static var offeredScenarios: [VirtualIDCard.Scenario] {
      VirtualIDCard.Scenario.allCases.filter { scenario in
        DemoMode.offersNearField || !scenario.usesNearField
      }
    }

    private static let minimumAttempts = 0
    private static let menuLineSpacing: CGFloat = 2

    /// The faults a demonstration on this device class can offer.
    private static var offeredFaultPresets: [VirtualIDCard.FaultPreset] {
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
        Menu {
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
        } label: {
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
    }

    internal var body: some View {
      NavigationStack {
        Form {
          scenarioSection
          Section(
            virtualCardLocalized("section.connection", defaultValue: "Connection")
          ) {
            if DemoMode.offersNearField {
              Picker(
                virtualCardLocalized(
                  "connection.transport",
                  defaultValue: "Transport"),
                selection: $draft.card.transport
              ) {
                Text(virtualCardLocalized("transport.nfc", defaultValue: "NFC"))
                  .tag(VirtualIDCard.Transport.nearField)
                Text(
                  virtualCardLocalized(
                    "transport.reader",
                    defaultValue: "Card reader")
                )
                .tag(VirtualIDCard.Transport.reader)
              }
              .pickerStyle(.segmented)
              .accessibilityIdentifier("virtualCardTransport")
            }
            Toggle(
              virtualCardLocalized(
                "connection.readerConnected",
                defaultValue: "Reader connected"),
              isOn: $draft.card.readerConnected
            )
            .accessibilityIdentifier("virtualCardReaderConnected")
            Toggle(
              virtualCardLocalized(
                "connection.cardPresent",
                defaultValue: "Card present"),
              isOn: $draft.card.cardPresent
            )
            .accessibilityIdentifier("virtualCardPresent")
            if DemoMode.offersNearField {
              TextField(
                virtualCardLocalized(
                  "connection.canShort",
                  defaultValue: "CAN"),
                text: $draft.card.cardAccessNumber,
                axis: .vertical
              )
              .keyboardType(.numberPad)
              .virtualCardEditorField()
              .padding(.leading, 1)
              .accessibilityIdentifier("virtualCardCAN")
              .accessibilityLabel(
                Text(
                  virtualCardLocalized(
                    "connection.can",
                    defaultValue: "Card Access Number (CAN)")))
            }
          }
          Section(
            virtualCardLocalized("section.identity", defaultValue: "Identity")
          ) {
            TextField(
              virtualCardLocalized("identity.name", defaultValue: "Name"),
              text: $draft.card.holderName,
              axis: .vertical
            )
            .virtualCardEditorField()
            .accessibilityIdentifier("virtualCardName")
            TextField(
              virtualCardLocalized(
                "identity.electronicClientIdentifier",
                defaultValue: "Electronic client identifier"),
              text: $draft.card.electronicClientIdentifier,
              axis: .vertical
            )
            .virtualCardEditorField()
            .accessibilityIdentifier("virtualCardElectronicIdentifier")
            TextField(
              virtualCardLocalized(
                "identity.tokenSerial",
                defaultValue: "Token serial"),
              text: $draft.card.tokenSerial,
              axis: .vertical
            )
            .virtualCardEditorField()
            .accessibilityIdentifier("virtualCardTokenSerial")
          }
          Section(
            virtualCardLocalized("section.activation", defaultValue: "Activation")
          ) {
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
          credentialSection(
            virtualCardLocalized("credential.pin1", defaultValue: "PIN 1"),
            identifier: "virtualCardPIN1",
            valueLabel: virtualCardLocalized(
              "credential.pin1Value",
              defaultValue: "PIN 1 value"),
            attemptsLabel: virtualCardLocalized(
              "credential.pin1Attempts",
              defaultValue: "PIN 1 attempts"),
            value: $draft.card.pin1.value,
            attempts: attemptsBinding(\.pin1))
          credentialSection(
            virtualCardLocalized("credential.pin2", defaultValue: "PIN 2"),
            identifier: "virtualCardPIN2",
            valueLabel: virtualCardLocalized(
              "credential.pin2Value",
              defaultValue: "PIN 2 value"),
            attemptsLabel: virtualCardLocalized(
              "credential.pin2Attempts",
              defaultValue: "PIN 2 attempts"),
            value: $draft.card.pin2.value,
            attempts: attemptsBinding(\.pin2))
          credentialSection(
            virtualCardLocalized("credential.puk", defaultValue: "PUK"),
            identifier: "virtualCardPUK",
            valueLabel: virtualCardLocalized(
              "credential.pukValue",
              defaultValue: "PUK value"),
            attemptsLabel: virtualCardLocalized(
              "credential.pukAttempts",
              defaultValue: "PUK attempts"),
            value: $draft.card.puk.value,
            attempts: attemptsBinding(\.puk))
          Section(
            virtualCardLocalized(
              "section.certificates",
              defaultValue: "Certificates")
          ) {
            Picker(
              virtualCardLocalized(
                "certificate.authentication",
                defaultValue: "Authentication"),
              selection: $draft.card.authenticationCertificate
            ) {
              certificateChoices
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .virtualCardMenuControl()
            .accessibilityIdentifier("virtualCardAuthenticationCertificate")
            Picker(
              virtualCardLocalized(
                "certificate.signature",
                defaultValue: "Signature"),
              selection: $draft.card.signatureCertificate
            ) {
              certificateChoices
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .virtualCardMenuControl()
            .accessibilityIdentifier("virtualCardSignatureCertificate")
          }
          Section(
            virtualCardLocalized(
              "section.deviceState",
              defaultValue: "Device state")
          ) {
            if DemoMode.offersNearField {
              TextField(
                virtualCardLocalized(
                  "device.storedCan",
                  defaultValue: "Stored CAN"),
                text: optionalBinding(\.storedCardAccessNumber),
                axis: .vertical
              )
              .keyboardType(.numberPad)
              .virtualCardEditorField()
              .accessibilityIdentifier("virtualCardStoredCAN")
              TextField(
                virtualCardLocalized(
                  "device.connectedCan",
                  defaultValue: "Connected CAN"),
                text: optionalBinding(\.connectedCardAccessNumber),
                axis: .vertical
              )
              .keyboardType(.numberPad)
              .virtualCardEditorField()
              .accessibilityIdentifier("virtualCardConnectedCAN")
            }
            Toggle(
              virtualCardLocalized(
                "device.pin1Stored",
                defaultValue: "PIN 1 stored"),
              isOn: $draft.device.hasPin1
            )
            .accessibilityIdentifier("virtualCardPIN1Stored")
            Toggle(
              virtualCardLocalized(
                "device.identityCached",
                defaultValue: "Identity cached"),
              isOn: $draft.device.cachedIdentity
            )
            .accessibilityIdentifier("virtualCardIdentityCached")
            Toggle(
              virtualCardLocalized(
                "device.tokenRegistered",
                defaultValue: "Token registered"),
              isOn: $draft.device.tokenRegistered
            )
            .accessibilityIdentifier("virtualCardTokenRegistered")
            Button {
              draft.device.pendingSigningRequest.toggle()
            } label: {
              LabeledContent(
                virtualCardLocalized(
                  "device.signingPending",
                  defaultValue: "Signing request pending")
              ) {
                Image(
                  systemName: draft.device.pendingSigningRequest
                    ? "checkmark.circle.fill"
                    : "circle")
              }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("virtualCardSigningPending")
            .accessibilityValue(
              Text(
                virtualCardLocalized(
                  draft.device.pendingSigningRequest
                    ? "state.enabled"
                    : "state.disabled",
                  defaultValue: draft.device.pendingSigningRequest
                    ? "Enabled"
                    : "Disabled")))
          }
          Section(
            virtualCardLocalized(
              "section.nextFault",
              defaultValue: "Next deterministic fault")
          ) {
            Menu {
              ForEach(Self.offeredFaultPresets, id: \.self) { preset in
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
            } label: {
              VStack(alignment: .leading, spacing: Self.menuLineSpacing) {
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
            .tint(.primary)
            .accessibilityIdentifier("virtualCardFault")
          }
        }
        .headerProminence(.increased)
        .navigationTitle(
          virtualCardLocalized("title", defaultValue: "Virtual ID Card")
        )
        .accessibilityIdentifier("virtualCardEditor")
        .toolbar {
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
      }
    }

    private var certificateChoices: some View {
      ForEach(VirtualIDCard.CertificateState.allCases, id: \.self) { state in
        Text(state.localizedName)
          .tag(state)
          .accessibilityIdentifier(
            "virtualCardCertificateOption.\(state.rawValue)")
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
      _ title: String,
      identifier: String,
      valueLabel: String,
      attemptsLabel: String,
      value: Binding<String>,
      attempts: Binding<Int>
    ) -> some View {
      Section(title) {
        TextField(valueLabel, text: value, axis: .vertical)
          .keyboardType(.numberPad)
          .virtualCardEditorField()
          .accessibilityIdentifier("\(identifier)Value")
        Stepper(
          value: attempts,
          in: Self.minimumAttempts...Int(RetryCount.pristineAllowance)
        ) {
          LabeledContent(attemptsLabel) {
            Text(String(attempts.wrappedValue))
          }
        }
        .accessibilityIdentifier("\(identifier)Attempts")
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

    private func optionalBinding(
      _ keyPath: WritableKeyPath<VirtualIDCard.DeviceState, String?>
    ) -> Binding<String> {
      Binding(
        get: { draft.device[keyPath: keyPath] ?? "" },
        set: { entered in
          draft.device[keyPath: keyPath] = entered.isEmpty ? nil : entered
        })
    }
  }

#endif
