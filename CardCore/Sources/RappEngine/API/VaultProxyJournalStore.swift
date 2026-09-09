// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Writes a proxy's durable records through the caller's vault.
///
/// Each call is one atomic storage transaction, so a record reaches storage
/// before the card is touched, never after.
internal struct VaultProxyJournalStore: JournalStore {
  private let vault: RappOperationVault
  private let pairIdentifier: Data

  internal init(vault: RappOperationVault, pairIdentifier: Data) {
    self.vault = vault
    self.pairIdentifier = pairIdentifier
  }

  internal mutating func persist(_ record: ProxyJournalRecord) throws {
    try vault.persistProxy(
      pairId: pairIdentifier,
      operationId: record.operationIdentifier,
      record: try record.encoded())
  }

  internal mutating func persistResult(
    _ record: ProxyJournalRecord,
    result: OperationResultMessage
  ) throws {
    try vault.persistProxyResult(
      pairId: pairIdentifier,
      operationId: record.operationIdentifier,
      record: try record.encoded(),
      result: try result.encoded())
  }

  internal mutating func retainUncertainResult(_ record: ProxyJournalRecord) throws {
    try vault.retainProxyUncertain(
      pairId: pairIdentifier,
      operationId: record.operationIdentifier,
      record: try record.encoded())
  }

  internal mutating func acknowledgeResult(_ record: ProxyJournalRecord) throws {
    try vault.acknowledgeProxyResult(
      pairId: pairIdentifier,
      operationId: record.operationIdentifier,
      record: try record.encoded())
  }
}
