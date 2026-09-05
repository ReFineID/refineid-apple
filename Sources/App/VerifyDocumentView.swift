// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore
  import SwiftUI
  import UniformTypeIdentifiers

  /// Verifies a chosen signed PDF and reports each signature's facts.
  internal struct VerifyDocumentView: View {
    private static let supportedDocumentTypes: [UTType] = {
      var types: [UTType] = [.pdf]
      if let asice = UTType("org.etsi.asic-e") ?? UTType(filenameExtension: "asice") {
        types.append(asice)
      }
      if let bdoc = UTType("ee.ria.bdoc") ?? UTType(filenameExtension: "bdoc") {
        types.append(bdoc)
      }
      return types
    }()

    @StateObject private var model = VerifyDocumentModel()
    @State private var importing = false

    internal var body: some View {
      Form {
        switch model.phase {
        case .idle:
          chooseSection

        case .verifying:
          Section {
            ProgressView(text("verify.progress", "Verifying"))
              .frame(maxWidth: .infinity)
          }

        case .report(let rows, let documentTimestampedAt):
          reportSections(rows, documentTimestampedAt: documentTimestampedAt)

        case .failed(let message):
          Section {
            CredentialOutcomeText(message: message, tone: .failure)
          }
          chooseSection
        }
      }
      .navigationTitle(text("verify.title", "Verify"))
      .fileImporter(
        isPresented: $importing,
        allowedContentTypes: Self.supportedDocumentTypes
      ) { result in
        if case .success(let url) = result {
          model.verify(url: url)
        }
      }
    }

    private var chooseSection: some View {
      Section {
        Button(text("verify.choose", "Choose a signed document")) {
          importing = true
        }
        .accessibilityIdentifier("verifyChooseDocument")
      }
    }

    @ViewBuilder
    private func reportSections(
      _ rows: [VerifyDocumentModel.SignatureRow],
      documentTimestampedAt: [Date]
    ) -> some View {
      Section {
        LabeledContent(text("signing.document", "Document")) {
          Text(model.documentName)
            .multilineTextAlignment(.trailing)
        }
        ForEach(documentTimestampedAt, id: \.self) { stamped in
          LabeledContent(text("verify.documentTimestamp", "Document timestamp")) {
            HStack {
              Text(stamped.formatted(date: .abbreviated, time: .shortened))
              CredentialValidationIndicator(valid: true)
            }
          }
        }
      }
      ForEach(rows, id: \.rowIndex) { row in
        signatureSection(row)
      }
      Section {
        Button(text("verify.another", "Verify another document")) {
          model.reset()
          importing = true
        }
        .accessibilityIdentifier("verifyAnotherDocument")
      }
    }

    private func signatureSection(
      _ row: VerifyDocumentModel.SignatureRow
    ) -> some View {
      Section {
        LabeledContent {
          Text(holder(of: row.report))
            .textSelection(.enabled)
            .multilineTextAlignment(.trailing)
            .accessibilityIdentifier("verifySigner")
        } label: {
          PersonRowLabel(configured: row.report.isValid)
        }
        factRow(
          text("verify.intact", "Document intact"),
          holds: row.report.documentIntact
        )
        factRow(
          text("verify.signature", "Signature"),
          holds: row.report.signatureValid
        )
        factRow(
          text("verify.chain", "Certificate chain"),
          holds: row.report.chainVerified
        )
        timestampRow(row.report)
        revocationRow(row.revocation)
      } header: {
        Text(text("verify.signature", "Signature"))
          .frame(maxWidth: .infinity, alignment: .leading)
          .listRowInsets(EdgeInsets())
      }
    }

    private func holder(
      of report: DocumentVerification.SignatureReport
    ) -> String {
      report.signerIdentifier.isEmpty
        ? report.signerName
        : "\(report.signerName) \(report.signerIdentifier)"
    }

    private func factRow(_ name: String, holds: Bool) -> some View {
      LabeledContent(name) {
        CredentialValidationIndicator(valid: holds)
      }
    }

    private func timestampRow(
      _ report: DocumentVerification.SignatureReport
    ) -> some View {
      LabeledContent(text("verify.timestamp", "Timestamp")) {
        HStack {
          if let timestampedAt = report.timestampedAt {
            Text(
              timestampedAt.formatted(
                date: .abbreviated, time: .shortened)
            )
          }
          CredentialValidationIndicator(valid: report.timestampsValid)
        }
      }
    }

    private func revocationRow(
      _ revocation: VerifyDocumentModel.Revocation
    ) -> some View {
      LabeledContent(text("verify.revocation", "Revocation")) {
        switch revocation {
        case .checking:
          ProgressView()

        case .good(let checkedAt):
          HStack {
            Text(
              checkedAt.formatted(date: .omitted, time: .shortened)
            )
            CredentialValidationIndicator(valid: true)
          }

        case .revoked:
          HStack {
            Text(text("verify.revoked", "Revoked"))
            CredentialValidationIndicator(valid: false)
          }

        case .unavailable:
          Text(text("verify.notChecked", "Not checked"))
            .foregroundStyle(.secondary)
        }
      }
    }

    private func text(
      _ key: StaticString,
      _ fallback: String.LocalizationValue
    ) -> String {
      String(localized: key, defaultValue: fallback, table: "DocumentSigning")
    }
  }

#endif
