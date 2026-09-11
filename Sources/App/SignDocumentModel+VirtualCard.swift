// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import Foundation

  extension SignDocumentModel {
    /// Authorizes and writes a simulated signature with the virtual ID card.
    internal func signWithVirtualCard(
      pin2: String,
      from source: URL,
      to destination: URL,
      appearance: Int
    ) async {
      let result = await DemoMode.shared.authorizeQualifiedSignature(pin2: pin2)
      guard appearance == cardAppearance else { return }
      switch result {
      case .success:
        do {
          let sourceData =
            (try? Data(contentsOf: source))
            ?? Data("%PDF-1.4\n% Virtual demonstration document\n%%EOF".utf8)
          try sourceData.write(to: destination, options: .atomic)
          complete(with: destination)
        } catch {
          fail(message: error.localizedDescription)
        }

      case .invalidEntry:
        fail(message: String(localized: "PIN 2 must contain 6 to 12 digits."))

      case .blocked:
        fail(
          message: String(
            localized: "PIN 2 is blocked. Reset it in PIN settings."
          )
        )

      case .rejected(let remaining):
        fail(
          message: String(localized: "PIN 2 is incorrect.")
            + "\n"
            + String(
              format: String(localized: "You have %d attempts remaining."),
              Int(remaining)
            )
        )

      case .refusedLowAttempts(let remaining):
        fail(
          message: String(localized: "Operation refused")
            + "\n"
            + String(
              format: String(localized: "You have %d attempts remaining."),
              Int(remaining)
            )
        )

      case .certificateUnavailable:
        fail(
          message: String(
            localized: "The signature certificate is unavailable."
          )
        )

      case .transportFailure:
        fail(message: String(localized: "The card connection was lost."))
      }
    }
  }

#endif
