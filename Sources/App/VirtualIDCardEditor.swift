// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) || os(macOS)

  import CardCore
  import SwiftUI

  /// Edits one complete virtual card/device snapshot and one fault plan.
  internal struct VirtualIDCardEditor: View {
    private enum Layout {
      #if os(macOS)
        static let headerSubtitleSpacing: CGFloat = 3
        static let headerHorizontalPadding: CGFloat = 24
        static let headerTopPadding: CGFloat = 18
        static let headerBottomPadding: CGFloat = 12
        static let footerSpacing: CGFloat = 12
        static let footerHorizontalPadding: CGFloat = 24
        static let footerVerticalPadding: CGFloat = 14
      #endif
    }

    // MARK: Static Computed Properties

    /// The scenarios a demonstration on this device class can offer.
    internal static var offeredScenarios: [VirtualIDCard.Scenario] {
      VirtualIDCard.Scenario.allCases.filter { scenario in
        DemoMode.offersNearField || !scenario.usesNearField
      }
    }

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
      Picker(
        virtualCardLocalized(
          "scenario.preset",
          defaultValue: "Preset"),
        selection: $scenario
      ) {
        ForEach(Self.offeredScenarios, id: \.self) { candidate in
          Text(candidate.localizedName)
            .tag(candidate)
            .accessibilityIdentifier(
              "virtualCardScenarioOption.\(candidate.rawValue)")
        }
      }
      .pickerStyle(.menu)
      .tint(.primary)
      .onValueChange(of: scenario) { selected in
        draft = Self.deviceScoped(selected.snapshot)
        faultPreset = .noFault
      }
      .virtualCardMenuControl()
      .accessibilityIdentifier("virtualCardScenario")
      .accessibilityLabel(
        Text(
          virtualCardLocalized(
            "scenario.accessibilityLabel",
            defaultValue: "Virtual card scenario")))
    }

    internal var body: some View {
      #if os(macOS)
        VStack(spacing: 0) {
          headerView
          Divider()
          ScrollView {
            Form {
              scenarioSection
              VirtualIDCardConnectionSection(draft: $draft)
              VirtualIDCardIdentitySection(draft: $draft)
              VirtualIDCardActivationSection(draft: $draft)
              VirtualIDCardCredentialsSection(draft: $draft)
              VirtualIDCardCertificatesSection(draft: $draft)
              VirtualIDCardDeviceSection(draft: $draft)
              VirtualIDCardFaultSection(faultPreset: $faultPreset)
            }
            .formStyle(.grouped)
          }
          Divider()
          footerBar
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("virtualCardEditor")
      #else
        NavigationStack {
          Form {
            scenarioSection
            VirtualIDCardConnectionSection(draft: $draft)
            VirtualIDCardIdentitySection(draft: $draft)
            VirtualIDCardActivationSection(draft: $draft)
            VirtualIDCardCredentialsSection(draft: $draft)
            VirtualIDCardCertificatesSection(draft: $draft)
            VirtualIDCardDeviceSection(draft: $draft)
            VirtualIDCardFaultSection(faultPreset: $faultPreset)
          }
          .headerProminence(.increased)
          .navigationTitle(
            virtualCardLocalized("title", defaultValue: "Virtual ID Card")
          )
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("virtualCardEditor")
          .toolbar {
            editorToolbar
          }
        }
      #endif
    }

    #if os(macOS)
      @ViewBuilder private var headerView: some View {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: Layout.headerSubtitleSpacing) {
            Text(virtualCardLocalized("title", defaultValue: "Virtual ID Card"))
              .font(.title2.bold())
            Text(
              virtualCardLocalized(
                "header.subtitle",
                defaultValue: "Simulated card and token state for testing")
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
      }

      @ViewBuilder private var footerBar: some View {
        HStack(spacing: Layout.footerSpacing) {
          Spacer()
          Button(
            virtualCardLocalized("action.cancel", defaultValue: "Cancel")
          ) {
            close()
          }
          .keyboardShortcut(.cancelAction)
          .accessibilityLabel(
            Text(
              virtualCardLocalized(
                "action.cancelAccessibilityLabel",
                defaultValue: "Cancel virtual card changes"))
          )
          .accessibilityIdentifier("virtualCardCancel")

          Button(
            virtualCardLocalized("action.apply", defaultValue: "Apply")
          ) {
            draft.faults = faultPreset.faults
            demoMode.replace(with: draft)
            close()
          }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
          .accessibilityLabel(
            Text(
              virtualCardLocalized(
                "action.applyAccessibilityLabel",
                defaultValue: "Apply virtual card changes"))
          )
          .accessibilityIdentifier("virtualCardApply")
        }
        .padding(.horizontal, Layout.footerHorizontalPadding)
        .padding(.vertical, Layout.footerVerticalPadding)
      }
    #endif

    #if os(iOS)
      @ToolbarContentBuilder private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
          Button(
            virtualCardLocalized("action.cancel", defaultValue: "Cancel")
          ) { close() }
          .accessibilityLabel(
            Text(
              virtualCardLocalized(
                "action.cancelAccessibilityLabel",
                defaultValue: "Cancel virtual card changes"))
          )
          .accessibilityIdentifier("virtualCardCancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(
            virtualCardLocalized("action.apply", defaultValue: "Apply")
          ) {
            draft.faults = faultPreset.faults
            demoMode.replace(with: draft)
            close()
          }
          .accessibilityLabel(
            Text(
              virtualCardLocalized(
                "action.applyAccessibilityLabel",
                defaultValue: "Apply virtual card changes"))
          )
          .accessibilityIdentifier("virtualCardApply")
        }
      }
    #endif

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

  }

#endif
