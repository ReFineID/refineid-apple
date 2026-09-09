// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

extension CardCredentialsView {
  private var managementDestination: some View {
    #if os(iOS)
      CardManagementView(cardAccessNumber: managementCardAccessNumber)
    #else
      CardManagementView()
    #endif
  }

  internal var managementSection: some View {
    Section("Manage") {
      NavigationLink {
        managementDestination
      } label: {
        Label("Personal Identification Numbers (PINs)", systemImage: "key")
      }
      .accessibilityIdentifier("manageCard")
    }
  }
}
