// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import RappEngine
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

internal enum RappApplePeerProfile {
  internal static let name = "apple-peer-v1"
  internal static let candidateID = "apple-peer-v1.nearby"

  /// Deterministic CBOR for an empty map.
  ///
  /// Apple peer discovery currently needs no public parameter beyond
  /// its bound profile and candidate ID.
  private static let emptyMapInitialByte: UInt8 = 0b1010_0000
  internal static let candidateParameters = Data([emptyMapInitialByte])

  /// Only profiles implemented end to end by the current phone executor.
  internal static let supportedCredentialProfiles = [
    "fi.refineid.card-status.v1",
    "fi.refineid.authentication.v1",
    "fi.refineid.document-signing.v1",
  ]

  internal static func isSupported(_ profile: String) -> Bool {
    supportedCredentialProfiles.contains(profile)
  }

  internal static func label(for profile: String) -> String {
    switch profile {
    case "fi.refineid.card-status.v1":
      String(localized: "Card status")

    case "fi.refineid.authentication.v1":
      String(localized: "Browser authentication")

    case "fi.refineid.document-signing.v1":
      String(localized: "Document signing")

    default:
      String(localized: "Unknown access")
    }
  }
}
