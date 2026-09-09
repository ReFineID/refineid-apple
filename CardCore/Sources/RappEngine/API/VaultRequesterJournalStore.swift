// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Writes a requester's durable records through the caller's vault.
internal struct VaultRequesterJournalStore: RequesterJournalStore {
  private let vault: RappOperationVault
  private let pairIdentifier: Data

  internal init(vault: RappOperationVault, pairIdentifier: Data) {
    self.vault = vault
    self.pairIdentifier = pairIdentifier
  }

  internal mutating func persist(_ record: RequesterJournalRecord) throws {
    try vault.persistRequester(
      pairId: pairIdentifier,
      operationId: record.operationIdentifier,
      record: try record.encoded())
  }
}
