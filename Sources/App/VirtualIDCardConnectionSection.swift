// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI

  /// The virtual card connection transport, reader presence, and card access number.
  internal struct VirtualIDCardConnectionSection: View {
    @Binding internal var draft: VirtualIDCard.Snapshot

    internal var body: some View {
      Section(
        virtualCardLocalized("section.connection", defaultValue: "Connection")
      ) {
        connectionTransportPicker
        connectionReaderToggles
        connectionCanField
      }
    }

    @ViewBuilder private var connectionTransportPicker: some View {
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
    }

    @ViewBuilder private var connectionReaderToggles: some View {
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
    }

    @ViewBuilder private var connectionCanField: some View {
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
  }

#endif
