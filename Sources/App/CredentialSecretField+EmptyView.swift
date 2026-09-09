// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

extension CredentialSecretField where Validation == EmptyView {
  internal init(
    name: String,
    text: Binding<String>,
    revealIdentifier: String,
    @ViewBuilder field: @escaping () -> Field
  ) {
    self.init(
      name: name,
      text: text,
      revealIdentifier: revealIdentifier,
      field: field
    ) { EmptyView() }
  }
}
