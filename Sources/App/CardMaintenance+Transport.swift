// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoTokenKit
import Foundation

extension CardMaintenance {
  internal enum Transport: String, CaseIterable, Sendable {
    case nearField = "nearField"
    case reader = "reader"

    internal var name: String {
      switch self {
      case .nearField:
        String(localized: "NFC")

      case .reader:
        String(localized: "Card reader")
      }
    }
  }

  internal static var availableTransports: [Transport] {
    #if REFINEID_LOCAL_CARD && os(iOS)
      if SupportedCardTransports.offersNearField {
        return [.reader, .nearField]
      }
    #endif
    return [.reader]
  }

  internal static var preferredTransport: Transport {
    guard let manager = TKSmartCardSlotManager.default else {
      return availableTransports.contains(.nearField) ? .nearField : .reader
    }
    let hasReader = manager.slotNames.contains { slotName in
      CardTransport.transport(forSlotNamed: slotName) == .reader
    }
    return hasReader || !availableTransports.contains(.nearField) ? .reader : .nearField
  }
}
