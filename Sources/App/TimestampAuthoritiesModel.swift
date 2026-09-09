// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import Foundation
  import Observation

  /// State for the Time-Stamp Authorities table: the rows being
  /// edited, and every write their editing triggers.
  ///
  /// The table edits two stores at once - the ordered list in
  /// preferences, and Basic-auth credentials split between preferences
  /// and the keychain - so both are reconciled from one place, after
  /// every change, keyed by row so a keystroke writes only the row it
  /// changed. Whoever configures an authority answers for it; nothing
  /// here probes or judges the service.
  @MainActor
  @Observable
  internal final class TimestampAuthoritiesModel {
    /// One row of the table.
    ///
    /// The identity must not be the address itself - rows are edited
    /// in place, and a row whose identity changed with every
    /// keystroke would lose focus after the first one.
    internal struct Row: Equatable {
      internal let rowID = UUID()
      internal var address = ""
      internal var username = ""
      internal var password = ""

      /// Nothing typed in any cell.
      internal var isBlank: Bool {
        address.isEmpty && username.isEmpty && password.isEmpty
      }
    }

    /// How long an entry rests before its scheme is completed.
    private static let typingRestDelay: Duration = .seconds(1)

    /// The rows, in the order the services are asked.
    internal var rows: [Row]

    /// What the stores already hold, keyed by row.
    private var saved: [UUID: Row]

    /// The completions in flight, keyed by row, so another keystroke
    /// restarts the row's rest timer.
    @ObservationIgnored private var completions: [UUID: Task<Void, Never>] = [:]

    /// Whether the table shows exactly the shipped set.
    internal var isShippedSet: Bool {
      rows.map(\.address).filter { !$0.isEmpty }
        == TimestampAuthorityStore.defaults
        && rows.allSatisfy { $0.username.isEmpty && $0.password.isEmpty }
    }

    internal init() {
      let loaded = Self.loadedRows()
      rows = loaded
      saved = Dictionary(uniqueKeysWithValues: loaded.map { ($0.rowID, $0) })
    }

    /// The stored authorities as rows, with the open line appended.
    private static func loadedRows() -> [Row] {
      var loaded = TimestampAuthorityStore.load().map { address in
        let credentials = TimestampAuthorityStore.credentials(for: address)
        return Row(
          address: address,
          username: credentials?.username ?? "",
          password: credentials?.password ?? ""
        )
      }
      loaded.append(Row())
      return loaded
    }

    /// The empty row at the bottom, waiting for the next authority.
    internal func isOpenLine(_ row: Row) -> Bool {
      row.isBlank && row.rowID == rows.last?.rowID
    }

    /// Writes what changed and keeps the open line open.
    internal func reconcile(focused: UUID?) {
      tidy(keeping: focused)
      scheduleCompletions()
      TimestampAuthorityStore.save(rows.map(\.address).filter { !$0.isEmpty })
      for row in rows where !row.address.isEmpty && saved[row.rowID] != row {
        TimestampAuthorityStore.saveCredentials(
          username: row.username, password: row.password, for: row.address
        )
      }
      forgetOrphans()
      saved = Dictionary(uniqueKeysWithValues: rows.map { ($0.rowID, $0) })
    }

    /// A blank row is kept only as the open line at the bottom, or
    /// while the cursor is still in it.
    internal func tidy(keeping focused: UUID?) {
      let lastIdentity = rows.last?.rowID
      rows.removeAll { row in
        row.isBlank && row.rowID != lastIdentity && row.rowID != focused
      }
      if rows.last?.isBlank != true {
        rows.append(Row())
      }
    }

    /// Back to the shipped authorities.
    ///
    /// Only the list itself is reset here: the writes that clear
    /// leftover credentials follow from the list change, through the
    /// same reconciliation every edit takes.
    internal func restoreDefaults() {
      TimestampAuthorityStore.restoreDefaults()
      rows = Self.loadedRows()
    }

    /// What happens once typing rests on a changed scheme-less
    /// address: it is completed with the scheme the service answers
    /// on (https preferred).
    ///
    /// Only an address the holder just changed in this pane is
    /// probed - never at launch, never on a schedule, never for the
    /// shipped set. Asking a service is observable traffic, and
    /// traffic on any other trigger would say who runs this software
    /// and when.
    private func scheduleCompletions() {
      for row in rows
      where !row.address.isEmpty && saved[row.rowID]?.address != row.address {
        completions[row.rowID]?.cancel()
        let (entry, identity) = (row.address, row.rowID)
        completions[identity] = Task { @MainActor in
          try? await Task.sleep(for: Self.typingRestDelay)
          guard !Task.isCancelled, !entry.contains("://") else { return }
          self.completeScheme(of: entry, at: identity)
        }
      }
    }

    /// Rewrites a rested scheme-less entry with the scheme the
    /// service answered on.
    private func completeScheme(of entry: String, at identity: UUID) {
      Task { @MainActor in
        guard
          let completed = await AuthoritySchemeResolver.complete(entry),
          let index = rows.firstIndex(where: { $0.rowID == identity }),
          rows[index].address == entry
        else { return }
        rows[index].address = completed
      }
    }

    /// An address deleted or renamed away keeps no credentials behind.
    private func forgetOrphans() {
      let current = Set(rows.map(\.address))
      for old in saved.values
      where !old.address.isEmpty && !current.contains(old.address) {
        TimestampAuthorityStore.saveCredentials(
          username: "", password: "", for: old.address
        )
      }
    }
  }

#endif
