// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import Foundation

  /// The visible stamp built from the identity the card supplied.
  extension SignDocumentModel {
    /// The placed mark and the exact certificate identity it states.
    internal func visibleStamp(on document: Data) -> DocumentSigner.VisibleStamp? {
      guard let state = stampState else { return nil }
      let rendered = StampRenderer.mark(state.statement)
      guard let placed = StampPlacement.placed(rendered, on: document) else {
        return nil
      }
      return DocumentSigner.VisibleStamp(
        mark: placed,
        signerCertificate: state.signerCertificate
      )
    }

    /// The portrait QR path, falling back to the existing mark when the
    /// card supplied no portrait.
    internal func signedVisibleStamp(
      on document: Data,
      source: URL,
      pin2: String,
      at instant: Date,
      style: DocumentStampStyle
    ) async throws -> DocumentSigner.VisibleStamp? {
      guard style == .portraitQr else {
        return self.visibleStamp(on: document)
      }
      guard let state = stampState else { return nil }
      guard
        let portraitBytes = state.portrait,
        let claim = StampAttestation.claim(
          identifier: state.statement.identifier,
          filename: source.lastPathComponent,
          at: instant
        )
      else {
        return self.visibleStamp(on: document)
      }
      let payload = try await DocumentSigner.attestation(
        over: claim,
        pin2: pin2,
        expectedCertificate: state.signerCertificate
      )
      guard
        let qrCode = QrCode.modules(of: payload),
        let fieldSide = StampRenderer.portraitFieldSide(
          forQrSide: qrCode.side
        ),
        let portrait = PortraitHalftone.map(
          imageData: portraitBytes,
          side: qrCode.side,
          fieldSide: fieldSide
        ),
        let qrPortrait = QrPortrait.artwork(qr: qrCode, portrait: portrait)
      else {
        throw StampPreparationFailure.rendering
      }
      let rendered = StampRenderer.mark(
        state.portraitStatement(qrPortrait: qrPortrait)
      )
      guard
        let placed = StampPlacement.placed(
          rendered,
          on: document,
          minimumShare: 1
        )
      else { return nil }
      return DocumentSigner.VisibleStamp(
        mark: placed,
        signerCertificate: state.signerCertificate
      )
    }
  }

#endif
