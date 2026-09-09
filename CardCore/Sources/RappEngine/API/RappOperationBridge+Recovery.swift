// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Resolving the records a crash interrupted, before operations begin.
extension RappOperationBridge {
  /// The proxy records stored for this pairing, with any record a crash
  /// interrupted resolved to its terminal state before operations begin.
  internal static func recoveredProxyRecords(
    vault: RappOperationVault, pairIdentifier: Data
  ) throws -> [RecoveredProxyRecord] {
    let stored: [RappStoredProxyJournal]
    do {
      stored = try vault.loadProxy(pairId: pairIdentifier)
    } catch {
      throw RappBindingError.LocalStateFailure
    }
    var store = VaultProxyJournalStore(vault: vault, pairIdentifier: pairIdentifier)
    return try stored.map { entry in
      let recovered: RecoveredProxyRecord
      do {
        recovered = RecoveredProxyRecord(
          record: try ProxyJournalRecord.decode(entry.record),
          retainedResult: try entry.retainedResult.map(OperationResultMessage.decode))
      } catch {
        throw RappBindingError.LocalStateFailure
      }
      return try recoveredAfterCrash(recovered, store: &store)
    }
  }

  /// Terminalizes one interrupted proxy record, never retrying it.
  ///
  /// Committed or executing becomes ambiguous; an unacknowledged retained
  /// result becomes delivery-uncertain and keeps its result. A terminal
  /// record passes through untouched.
  private static func recoveredAfterCrash(
    _ recovered: RecoveredProxyRecord, store: inout VaultProxyJournalStore
  ) throws -> RecoveredProxyRecord {
    var journal = OperationJournal(recovered: recovered.record)
    do {
      switch recovered.record.state {
      case .committed, .executing:
        try journal.recoverAfterCrash(to: &store)

      case .resultPending:
        try journal.markDeliveryUncertain(to: &store)

      default:
        return recovered
      }
    } catch {
      throw RappBindingError.LocalStateFailure
    }
    return RecoveredProxyRecord(
      record: journal.record, retainedResult: recovered.retainedResult)
  }

  /// The requester records stored for this pairing, with any record a
  /// crash interrupted resolved to its terminal state.
  ///
  /// The classification is the session-closure one: a crash closed the
  /// session, so an uncommitted record cancels, a committed one becomes
  /// ambiguous, and an unacknowledged result becomes delivery-uncertain.
  internal static func recoveredRequesterRecords(
    vault: RappOperationVault, pairIdentifier: Data
  ) throws -> [RequesterJournalRecord] {
    let stored: [Data]
    do {
      stored = try vault.loadRequester(pairId: pairIdentifier)
    } catch {
      throw RappBindingError.LocalStateFailure
    }
    var store = VaultRequesterJournalStore(vault: vault, pairIdentifier: pairIdentifier)
    return try stored.map { bytes in
      var record: RequesterJournalRecord
      do {
        record = try RequesterJournalRecord.decode(bytes)
      } catch {
        throw RappBindingError.LocalStateFailure
      }
      let terminal: OperationState
      switch record.state {
      case .requested, .awaitingConsent, .prepared:
        terminal = .cancelled

      case .committed, .executing:
        terminal = .ambiguous

      case .resultPending:
        terminal = .deliveryUncertain

      default:
        return record
      }
      record.state = terminal
      do {
        try store.persist(record)
      } catch {
        throw RappBindingError.LocalStateFailure
      }
      return record
    }
  }
}
