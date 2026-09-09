// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// A rolling record of what the extensions did, kept where the containing
/// app can read it.
///
/// The extensions run inside `ctkd`, and on iOS 26 there is no way in from
/// a cable: `log stream --device` is gone, `log collect` fails, and the
/// file ``TokenLog`` writes sits in a container no other process may open.
/// A failure in there is therefore indistinguishable from any other
/// failure, which is precisely the position a card that will not prime and
/// will not sign leaves us in. So the extensions write their trace here as
/// well, into a keychain item in the access group all three binaries share
/// -- the same channel the primed identity travels on -- and the app's
/// diagnostics screen shows it.
///
/// The buffer is bounded at ``maximumBytes`` and drops the oldest half
/// when it overflows. A trace that grows without limit becomes an item
/// nobody wants to write, and the lines that matter are always the last
/// ones. Halving rather than dropping one line at a time keeps the cost of
/// an append flat: the expensive trim happens once per several hundred
/// lines instead of on every line past the cap. Two processes appending in
/// the same instant can lose a line, which is accepted: this is an
/// instrument for reading control flow, not a ledger.
///
/// Nothing secret is written. Sizes, INS bytes, status words, timings and
/// typed reasons only -- never a PIN, a card access number, a serial or a
/// holder name (release plan section 4.3). A fact that could only be
/// stated by naming one of those is not traced at all: the buffer is a
/// plaintext keychain item for as long as it is held, and it is read by a
/// screen the holder can share from.
///
/// The item is `WhenUnlockedThisDeviceOnly`, matching ``PrimeStore``:
/// every path that writes here is a path that has just read a prime, so
/// nothing is lost by using the same policy, and a diagnostic buffer has
/// no business being readable in a state the identity it describes is
/// not. Non-synchronizable, so it is never backed up, restored elsewhere,
/// or sent to iCloud. `kSecUseDataProtectionKeychain` must be set
/// identically on both sides or the writer and the reader address
/// different keychains and silently never see each other's writes.
///
/// Provenance: the `fi.refineid.tokenlog` shared trace that `--dump-ctk`
/// reads in the donor `platform/apple/RefineID/Shared/RefineIDApp.swift`,
/// whose buffer was written through on every line; this one can also
/// record without writing, because the contactless field is too short to
/// spend on a keychain round trip per APDU.
public enum ExtensionTrace {
  /// Lines recorded in memory but not yet written to the shared item.
  ///
  /// `@unchecked Sendable` is sound because every access holds the lock:
  /// CryptoTokenKit calls a token on its own threads and a slot-state
  /// observation fires on another, so two writers are the ordinary case
  /// rather than an exotic one.
  internal final class Pending: @unchecked Sendable {
    /// Serialises the threads that reach the waiting lines.
    private let lock = NSLock()

    /// The lines waiting to be written, oldest first.
    private var lines: [String] = []

    /// Adds one line to the waiting set.
    internal func record(_ line: String) {
      lock.lock()
      defer { lock.unlock() }
      lines.append(line)
    }

    /// Removes and returns everything waiting.
    internal func drain() -> [String] {
      lock.lock()
      defer { lock.unlock() }
      let drained = lines
      lines.removeAll()
      return drained
    }
  }

  /// How large the stored trace may grow, in bytes.
  ///
  /// Big enough to hold several whole login attempts end to end, small
  /// enough that reading and rewriting it stays cheap.
  public static let maximumBytes: Int = 20_000

  /// How much of the buffer a trim keeps: the newer half.
  public static let survivingFraction: Int = 2

  /// Keychain service the trace lives under.
  private static let service: String = "fi.refineid.trace"

  /// Single well-known account: one trace per device.
  private static let account: String = "latest"

  /// Cap on one line, so a single runaway message cannot displace the
  /// whole trace.
  private static let maximumLineLength: Int = 512

  /// Separates two lines in the stored blob.
  private static let separator: Character = "\n"

  /// What a line may not contain: the blob is line-delimited, so a line
  /// carrying its own delimiter could forge trace entries.
  private static let forbidden: CharacterSet = .newlines

  /// The lines recorded in this process but not yet written out.
  private static let pending = Pending()

  /// Appends one line and writes the buffer out immediately.
  ///
  /// Never throws and never reports: a diagnostic that can fail a caller
  /// is a diagnostic that gets removed from the path it was meant to
  /// watch. Use this everywhere the cost of a keychain round trip does
  /// not matter, which is everywhere outside a live contactless field.
  public static func append(_ line: String) {
    Self.pending.record(Self.stamped(line))
    Self.flush()
  }

  /// Empties the trace, in memory and on the device.
  ///
  /// Every measurement starts from a known zero, or an old line reads as
  /// if the new run had made it.
  /// Answers with the keychain's own status, so a clear that did not
  /// clear says why instead of looking like a button that does nothing.
  @discardableResult
  public static func clear() -> OSStatus {
    _ = Self.pending.drain()
    return SecItemDelete(Self.query() as CFDictionary)
  }

  /// Writes everything recorded so far into the shared item.
  public static func flush() {
    let recorded = Self.pending.drain()
    guard !recorded.isEmpty else { return }
    var buffer = Self.storedText() ?? ""
    for line in recorded {
      buffer += line + String(Self.separator)
    }
    Self.write(Self.trimmed(buffer))
  }

  /// Records one line without paying for a keychain write.
  ///
  /// The contactless path has about two seconds of field for a whole
  /// signature, and a keychain round trip per APDU spends it on the wrong
  /// thing. Lines recorded this way reach the item at the next
  /// ``append(_:)``, ``flush()`` or ``read()`` -- all of which happen once
  /// the operation that produced them has ended.
  public static func record(_ line: String) {
    Self.pending.record(Self.stamped(line))
  }

  /// Every line currently held, oldest first.
  ///
  /// Flushes before reading, so a caller inside the writing process is
  /// never shown a trace that is missing what it just recorded.
  public static func read() -> [String] {
    Self.flush()
    guard let text = Self.storedText(), !text.isEmpty else { return [] }
    return
      text
      .split(separator: Self.separator)
      .map(String.init)
  }

  /// The tail of `buffer` that fits the cap, cut on line boundaries.
  ///
  /// The rule, and not the keychain around it, is what can be wrong here,
  /// so it is a pure function: a test exercises this directly, which it
  /// could not do through storage that needs an entitlement.
  public static func trimmed(_ buffer: String) -> String {
    var text = buffer
    while text.utf8.count > Self.maximumBytes {
      let lines = text.split(separator: Self.separator, omittingEmptySubsequences: false)
      guard lines.count > 1 else { break }
      text =
        lines
        .suffix(max(1, lines.count / Self.survivingFraction))
        .joined(separator: String(Self.separator))
    }
    return text
  }

  /// Item coordinates shared by every operation.
  ///
  /// The accessibility attribute is deliberately absent here: it belongs
  /// on the write, and a search that filtered on it would miss an item
  /// written under any other policy instead of replacing it.
  private static func query() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      kSecUseDataProtectionKeychain as String: KeychainPlatform.usesDataProtection,
      kSecAttrSynchronizable as String: false,
    ]
  }

  /// When a line was written, to the millisecond.
  ///
  /// Millisecond precision is the point of the stamp: two signatures
  /// inside the same second are the ordinary case on a TLS handshake, and
  /// a trace that cannot tell them apart cannot say which one failed. A
  /// fresh formatter per call -- `ISO8601DateFormatter` is not `Sendable`
  /// and the line volume is far too low for the cost to register.
  private static func stamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }

  /// One line stamped, flattened onto a single line, and clamped.
  private static func stamped(_ line: String) -> String {
    let flattened = line.components(separatedBy: Self.forbidden).joined(separator: " ")
    return Self.stamp() + " " + String(flattened.prefix(Self.maximumLineLength))
  }

  /// The stored blob, or nil when nothing has been traced yet.
  private static func storedText() -> String? {
    var search = Self.query()
    search[kSecReturnData as String] = true
    search[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  /// Replaces the stored blob, creating the item when there is none.
  private static func write(_ text: String) {
    let data = Data(text.utf8)
    let updated = SecItemUpdate(
      Self.query() as CFDictionary,
      [kSecValueData as String: data] as CFDictionary
    )
    guard updated == errSecItemNotFound else { return }
    var insert = Self.query()
    insert[kSecValueData as String] = data
    insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    SecItemAdd(insert as CFDictionary, nil)
  }
}
