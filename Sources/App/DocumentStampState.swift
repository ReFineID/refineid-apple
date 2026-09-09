// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import Foundation

  /// One visible statement and the exact certificate that states it.
  internal struct DocumentStampState {
    internal let statement: StampRenderer.Statement
    internal let signerCertificate: Data
    internal let portrait: Data?

    /// Reuses the exact certificate names captured with the card portrait.
    internal func portraitStatement(
      qrPortrait: QrPortrait.Artwork
    ) -> StampRenderer.Statement {
      StampRenderer.Statement(
        name: statement.name,
        identifier: statement.identifier,
        signature: statement.signature,
        qrPortrait: qrPortrait,
        givenName: statement.givenName,
        surname: statement.surname
      )
    }
  }

#endif
