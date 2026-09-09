// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD
  import CardCore
  import Foundation
  import RappEngine
  /// Resolves the phone's one usable selected pair for a proxy connection.
  internal enum PhoneProxyPairSelection {
    /// Loads the selected active pair record, selecting a sole active pair
    /// on the way and clearing a stale selection.
    ///
    /// Nil means no single usable pair exists; an unloadable stored record
    /// surfaces as its load error.
    internal static func resolveSelectedPair(
      vault: RappDeviceVault
    ) throws -> RappPairRecord? {
      let pairIDs = try vault.activePairIDs()
      guard !pairIDs.isEmpty else { return nil }
      let pairID: Data
      if let selected = try vault.selectedPairID(), pairIDs.contains(selected) {
        pairID = selected
      } else {
        pairID = pairIDs[0]
        try? vault.selectPair(pairID: pairID)
      }
      return try RappPairRecord.loadFromVault(pairId: pairID, vault: vault)
    }
  }
#endif
