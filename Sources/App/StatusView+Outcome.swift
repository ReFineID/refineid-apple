// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import SwiftUI

  /// What the window says when signing went wrong.
  ///
  /// Success says nothing: the pile empties and the file is where it
  /// was asked for, and a readout naming one output cannot speak for
  /// a batch that wrote several.
  extension StatusView {
    @ViewBuilder internal var outcomeSection: some View {
      if signingModel.failure != nil || signingModel.notice != nil {
        Section {
          if let failure = signingModel.failure {
            CredentialOutcomeText(message: failure, tone: .failure)
          }
          if let note = signingModel.notice {
            CredentialOutcomeText(message: note, tone: .notice)
          }
        }
      }
    }
  }

#endif
