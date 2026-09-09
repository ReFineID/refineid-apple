// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// The card access number as the app offers it to the token driver,
/// through the app group container both are entitled to read.
///
/// The configuration store cannot carry it:
/// `TKTokenDriver.Configuration.driverConfigurations` is populated for
/// the hosting application only, and every other caller - the token
/// driver included - is handed an empty store, so a number written
/// there is unreadable exactly where it is needed. The group container
/// is the one place the app can write and the driver can read.
///
/// The number is a proximity proof printed on the card face, offered
/// while its card is present and withdrawn with it; the file holds the
/// digits for that long and no longer.
public enum OfferedAccessNumber {
  #if os(macOS)
    /// The entitlement whose value names the app group to use.
    private static let appGroupEntitlement =
      "com.apple.security.application-groups"
  #endif

  /// The file the digits travel in.
  private static let filename = "offered-access-number"

  /// The marker the driver leaves when the card refused the offer.
  ///
  /// The refusal happens in the token extension, which has no window
  /// to say so in; the app watches for this file and shows the
  /// refusal where the number was typed.
  private static let refusalFilename = "offered-access-number-refused"

  /// Owner read and write, nobody else.
  private static let ownerOnly = 0o600

  /// Where the file lives, or nil without the entitlement.
  private static var url: URL? {
    container?.appendingPathComponent(filename, isDirectory: false)
  }

  /// Where the refusal marker lives.
  private static var refusalUrl: URL? {
    container?.appendingPathComponent(refusalFilename, isDirectory: false)
  }

  #if os(macOS)
    /// The app group this binary is entitled to, read from its own
    /// entitlements so no team identifier is written in source.
    ///
    /// Nil when the binary carries no application-group entitlement,
    /// which is the shipped macOS release - contactless is gated out
    /// there, so the whole channel is absent. Self-consistent by
    /// construction: it uses whatever group the binary actually holds.
    ///
    /// `SecTaskCopyValueForEntitlement` is macOS-only; the channel is
    /// too, so this whole path is guarded. iOS carries the access
    /// number in the shared keychain access group instead.
    private static var appGroup: String? {
      guard let task = SecTaskCreateFromSelf(nil) else { return nil }
      var error: Unmanaged<CFError>?
      let value = SecTaskCopyValueForEntitlement(
        task, appGroupEntitlement as CFString, &error)
      return (value as? [String])?.first
    }
  #endif

  /// The group container, or nil where there is none - which is iOS
  /// entirely, and macOS without the entitlement.
  private static var container: URL? {
    #if os(macOS)
      guard let appGroup else { return nil }
      return FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    #else
      return nil
    #endif
  }

  /// The offered digits, or nil when nothing is offered.
  internal static func digits() -> String? {
    guard let url, let data = try? Data(contentsOf: url) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  /// Offers `digits`, replacing any previous offer and clearing the
  /// previous offer's fate.
  @discardableResult
  internal static func publish(digits: String) -> Bool {
    guard let url else { return false }
    clearRefusal()
    do {
      try Data(digits.utf8).write(to: url, options: [.atomic])
      try FileManager.default.setAttributes(
        [.posixPermissions: Self.ownerOnly], ofItemAtPath: url.path)
      return true
    } catch {
      return false
    }
  }

  /// Withdraws the offer, marker included.
  internal static func withdraw() {
    clearRefusal()
    guard let url else { return }
    try? FileManager.default.removeItem(at: url)
  }

  /// Records that the card refused the offered number.
  internal static func recordRefusal() {
    guard let refusalUrl else { return }
    try? Data().write(to: refusalUrl, options: [.atomic])
  }

  /// Whether the offered number stands refused.
  internal static func refusalRecorded() -> Bool {
    guard let refusalUrl else { return false }
    return FileManager.default.fileExists(atPath: refusalUrl.path)
  }

  /// Clears the refusal, for an offer that succeeded after all.
  internal static func clearRefusal() {
    guard let refusalUrl else { return }
    try? FileManager.default.removeItem(at: refusalUrl)
  }

  /// Where a read that found nothing actually failed: each step of
  /// the path, never any digits.
  ///
  /// For the driver's log. The app and the driver resolve the
  /// container independently, and a miss on one side of a file the
  /// other side wrote can only be told apart by asking the failing
  /// process itself.
  public static func missDescription() -> String {
    guard let container else { return "container unresolved" }
    guard let url else { return "path unresolved" }
    let directoryExists = FileManager.default.fileExists(atPath: container.path)
    let fileExists = FileManager.default.fileExists(atPath: url.path)
    var readOutcome = "ok"
    do {
      _ = try Data(contentsOf: url)
    } catch {
      readOutcome = String(describing: error)
    }
    return "container=\(container.path) directory=\(directoryExists) "
      + "file=\(fileExists) read=\(readOutcome)"
  }
}
