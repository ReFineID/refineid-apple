// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI

  /// The virtual card authentication and signature certificate pickers.
  internal struct VirtualIDCardCertificatesSection: View {
    @Binding internal var draft: VirtualIDCard.Snapshot

    internal var body: some View {
      certificatesContent
    }

    private var certificateChoices: some View {
      ForEach(VirtualIDCard.CertificateState.allCases, id: \.self) { state in
        Text(state.localizedName)
          .tag(state)
          .accessibilityIdentifier(
            "virtualCardCertificateOption.\(state.rawValue)")
      }
    }

    @ViewBuilder private var certificatesContent: some View {
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
    }
  }

#endif
