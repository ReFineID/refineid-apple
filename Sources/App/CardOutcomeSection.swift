// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

/// What a card-management operation said: progress, failure, or the
/// accepted result - one section, wherever the operation ran.
///
/// The model is observed, not just held: without the subscription
/// this section keeps its first evaluation while the form above it
/// moves on, and an outcome the card published never appears.
internal struct CardOutcomeSection: View {
  /// The model whose operation is being reported on.
  @ObservedObject internal var model: CardManagementModel

  internal var body: some View {
    if model.failure != nil || model.notice != nil {
      Section {
        if let failure = model.failure {
          CredentialOutcomeText(message: failure, tone: .failure)
        }
        if let notice = model.notice {
          CredentialOutcomeText(message: notice, tone: .success)
        }
      }
    }
  }
}
