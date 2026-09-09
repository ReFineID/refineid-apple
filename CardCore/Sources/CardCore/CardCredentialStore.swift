// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Security

/// Where this device keeps the card access number, and optionally PIN1.
///
/// PIN1 is never handed back for display: written once, present-or-absent
/// afterwards. The card access number is the holder's to see -- it is
/// printed on the card face -- and ``displayedCardAccessNumber()`` returns
/// it for the manager window. Neither enters a log.
///
/// Both are `WhenUnlockedThisDeviceOnly` and non-synchronizable, so
/// neither is written into a backup, restored onto another device, or
/// sent to iCloud. Neither attribute implies the other; both are set.
///
/// Neither item carries a `SecAccessControl`, and storage is ungated.
/// The token extension reads the stored value while signing a Safari
/// request and has no interface to answer a prompt, so an item-level
/// gate cannot serve this flow; the card's own retry counter is the
/// control that stops a guessed PIN, and deletion reveals nothing. The
/// reasoning and the trade are in `Documentation/decisions.md`.
public enum CardCredentialStore {
  // MARK: Nested Types

  /// What the store currently holds.
  public struct Contents: Equatable, Sendable {
    // MARK: Properties

    /// Whether a card access number is stored.
    public let hasCardAccessNumber: Bool

    /// Whether PIN1 is stored for unattended signing.
    public let hasPin1: Bool

    /// Whether PIN2 is stored for unattended testing.
    public let hasPin2: Bool

    // MARK: Lifecycle

    /// Records what a store lookup found.
    public init(hasCardAccessNumber: Bool, hasPin1: Bool, hasPin2: Bool = false) {
      self.hasCardAccessNumber = hasCardAccessNumber
      self.hasPin1 = hasPin1
      self.hasPin2 = hasPin2
    }
  }

  // MARK: Static Properties

  /// Posted in-process whenever the stored CAN is explicitly removed.
  ///
  /// The app uses this to clear any visible copy immediately after the
  /// card rejects PACE. It is deliberately an event rather than polling.
  public static let cardAccessNumberDidInvalidate =
    Notification.Name("fi.refineid.card-access-number-did-invalidate")

  /// Keychain service the card credentials live under.
  internal static let service = "fi.refineid.credentials"

  /// Account for the card access number.
  private static let cardAccessNumberAccount = "can"

  /// Account for PIN1, present only when the holder opted in.
  private static let pin1Account = "pin1"

  /// Account for PIN2, present only when configured for test automation.
  private static let pin2Account = "pin2"

  /// Keychain coordinates used by the retired timed signing window.
  private static let legacySigningWindowService = "fi.refineid.pin1window"
  private static let legacySigningWindowAccount = "current"

  // MARK: Static Functions

  /// What is stored, without reading any secret.
  public static func contents() -> Contents {
    Contents(
      hasCardAccessNumber: exists(account: cardAccessNumberAccount),
      hasPin1: exists(account: pin1Account),
      hasPin2: exists(account: pin2Account))
  }

  /// Stores the card access number, replacing any previous one.
  ///
  /// Also hands it to the token driver, which on macOS cannot read the
  /// keychain item this just wrote. See `publishCardAccessNumberToDriver`.
  @discardableResult
  public static func save(cardAccessNumber digits: String) -> OSStatus {
    guard CardAccessNumber(digits: digits) != nil else { return errSecParam }
    let status = write(digits, account: cardAccessNumberAccount)
    if status == errSecSuccess {
      publishToDriver(digits: digits)
    }
    return status
  }

  /// An opaque name for the stored number: equal when the number is,
  /// never convertible back to digits.
  ///
  /// Lets the token driver remember "this exact number was refused by
  /// this card" across offers without holding digits, which is what
  /// stops a wrong number from being retried against the card for as
  /// long as it rests on the antenna.
  public static func cardAccessNumberFingerprint() -> Data? {
    var digits = read(account: cardAccessNumberAccount).map { Data($0.utf8) }
    #if os(macOS)
      if digits == nil {
        digits = OfferedAccessNumber.digits().map { Data($0.utf8) }
      }
    #endif
    guard let digits else { return nil }
    return Data(SHA256.hash(data: digits))
  }

  /// Hands the stored card access number to the token driver, for the
  /// platform where it cannot read the keychain item itself.
  ///
  /// Called by the app when it starts, not only when the number is
  /// entered: a number stored before this channel existed, or by a
  /// previous version, would otherwise stay invisible to the driver
  /// until the holder happened to type it again.
  ///
  /// Answers whether anything was published, so a caller can say so.
  /// False covers both nothing stored and a process that is not the
  /// driver's hosting application, neither of which is an error.
  @discardableResult
  public static func publishCardAccessNumberToDriver() -> Bool {
    guard let digits = read(account: cardAccessNumberAccount) else { return false }
    return publishToDriver(digits: digits)
  }

  /// Publishes a just-typed card access number for the driver's next
  /// unseal, keeping it nowhere else.
  ///
  /// This is the macOS route for a sealed contactless card: the holder
  /// types the number where the card appeared, the driver reads it for
  /// the mint, and `withdrawCardAccessNumberFromDriver` takes it back
  /// once the card is published or gone. Nothing is written to the
  /// keychain, so nothing survives to be a previously saved number.
  @discardableResult
  public static func publishCardAccessNumberToDriver(digits: String) -> Bool {
    guard CardAccessNumber(digits: digits) != nil else { return false }
    return publishToDriver(digits: digits)
  }

  /// Withdraws the published number, and the configuration-store
  /// entry earlier versions published, which must not outlive them.
  public static func withdrawCardAccessNumberFromDriver() {
    #if os(macOS)
      OfferedAccessNumber.withdraw()
      DriverConfiguredCredentials.withdraw()
    #endif
  }

  /// Records that the card refused the offered number, where the
  /// window that offered it can see - the token driver has no window
  /// of its own to say so in.
  public static func recordOfferedNumberRefusal() {
    #if os(macOS)
      OfferedAccessNumber.recordRefusal()
    #endif
  }

  /// Whether the offered number stands refused by the card.
  public static func offeredNumberWasRefused() -> Bool {
    #if os(macOS)
      return OfferedAccessNumber.refusalRecorded()
    #else
      return false
    #endif
  }

  /// Clears a recorded refusal, for the offer that succeeded.
  public static func clearOfferedNumberRefusal() {
    #if os(macOS)
      OfferedAccessNumber.clearRefusal()
    #endif
  }

  /// The stored card access number, for the holder to see.
  ///
  /// The number is printed on the card face; hiding it from its holder
  /// protected nothing and cost the manager window its one job. PIN1
  /// has no counterpart to this, and the value still never reaches a
  /// log, a trace or a diagnostics export.
  public static func displayedCardAccessNumber() -> String? {
    read(account: cardAccessNumberAccount)
  }

  /// Stores PIN1 for unattended signing, replacing any previous one.
  ///
  /// Storing PIN1 trades the rule that one signature costs one PIN entry:
  /// anything that can reach the token can then sign without the holder
  /// present. Offer it as a choice, never as a default, and say so where
  /// the choice is made.
  @discardableResult
  public static func save(pin1 digits: String) -> OSStatus {
    guard Pin1(digits: digits) != nil else { return errSecParam }
    return write(digits, account: pin1Account)
  }

  /// Stores PIN2 for unattended testing, replacing any previous one.
  @discardableResult
  public static func save(pin2 digits: String) -> OSStatus {
    guard Pin2(digits: digits) != nil else { return errSecParam }
    return write(digits, account: pin2Account)
  }

  /// The stored card access number.
  ///
  /// Reads without prompting: the number is printed on the card, and a
  /// prompt in front of it would cost the holder an interruption on
  /// every card setup for very little.
  public static func cardAccessNumber() -> CardAccessNumber? {
    if let stored = read(account: cardAccessNumberAccount)
      .flatMap(CardAccessNumber.init(digits:))
    {
      return stored
    }
    // The app's offer in the group container, which on macOS is the
    // only copy the driver can read. Second rather than first, so the
    // keychain stays the source of truth wherever it is readable.
    #if os(macOS)
      return OfferedAccessNumber.digits().flatMap(CardAccessNumber.init(digits:))
    #else
      return nil
    #endif
  }

  /// The keychain's own answer to "could the card access number be read
  /// from this process?", for when it could not.
  ///
  /// `cardAccessNumber()` answers nil for every reason there is, and the
  /// reasons want different things done about them: `errSecItemNotFound`
  /// is setup that has not happened, while a refusal is one process
  /// being unable to read what another one wrote. A caller that has
  /// already failed can say which it hit instead of guessing.
  /// Asks for the value, not merely the item: on macOS the two are
  /// different questions, because finding an item needs no authorization
  /// while reading its data is what the access control governs. A probe
  /// that omitted the data reported success for an item it could not
  /// actually read.
  public static func cardAccessNumberReadStatus() -> OSStatus {
    if TestCredentialEnvironment.isTestMode {
      return read(account: cardAccessNumberAccount) != nil ? errSecSuccess : errSecItemNotFound
    }
    var query = self.query(account: cardAccessNumberAccount)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    return SecItemCopyMatching(query as CFDictionary, &item)
  }

  /// The stored PIN1, or nil when the holder never entered one.
  public static func pin1() -> Pin1? {
    read(account: pin1Account).flatMap(Pin1.init(digits:))
  }

  /// The stored PIN1 digits, or nil when the holder never entered one.
  public static func pin1Digits() -> String? {
    read(account: pin1Account)
  }

  /// The stored PIN2, or nil when none is stored.
  public static func pin2() -> Pin2? {
    read(account: pin2Account).flatMap(Pin2.init(digits:))
  }

  /// The stored PIN2 digits, or nil when none is stored.
  public static func pin2Digits() -> String? {
    read(account: pin2Account)
  }

  /// Removes the duplicate PIN item written by builds with a timed
  /// signing window.
  ///
  /// Current builds sign directly from the holder's explicitly stored
  /// credential, so the derived copy has no reader and must not survive
  /// an upgrade indefinitely.
  public static func removeLegacySigningWindow() {
    guard !TestCredentialEnvironment.isTestMode else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: legacySigningWindowService,
      kSecAttrAccount as String: legacySigningWindowAccount,
      kSecUseDataProtectionKeychain as String: KeychainPlatform.usesDataProtection,
      kSecAttrSynchronizable as String: false,
    ]
    SecItemDelete(query as CFDictionary)
  }

  /// The primed identity for a card that was just read, built around the
  /// stored card access number.
  ///
  /// The prime store needs the six digits, and this type is where they
  /// live. Handing them out so a caller could assemble the record itself
  /// would put a card access number in a `String` in the app, in the
  /// extension, and in every caller added later; assembling the record
  /// here means the digits go from the keychain into the prime without
  /// passing through any other file. Returns nil when nothing is stored
  /// or the record would not validate.
  public static func primedIdentity(
    certificate: Data,
    issuer: Data?,
    tokenSerial: String?,
    activationCheck: PrimedIdentity.ActivationCheck,
    signatureCertificate: Data? = nil
  ) -> PrimedIdentity? {
    guard let digits = read(account: cardAccessNumberAccount) else {
      return nil
    }
    return PrimedIdentity(
      can: digits,
      certificate: certificate,
      issuer: issuer,
      tokenSerial: tokenSerial,
      activationCheck: activationCheck,
      signatureCertificate: signatureCertificate)
  }

  /// Removes the card access number, from the driver's copy as well.
  public static func forgetCardAccessNumber() {
    delete(account: cardAccessNumberAccount)
    NotificationCenter.default.post(
      name: cardAccessNumberDidInvalidate,
      object: nil)
    #if os(macOS)
      OfferedAccessNumber.withdraw()
      DriverConfiguredCredentials.withdraw()
    #endif
  }

  /// Removes PIN1, returning to a prompt for every signature.
  public static func forgetPin1() {
    delete(account: pin1Account)
  }

  /// Removes PIN2, returning to a prompt for every signature.
  public static func forgetPin2() {
    delete(account: pin2Account)
  }

  /// Removes everything this device knows about the card's secrets.
  public static func forgetAll() {
    delete(account: cardAccessNumberAccount)
    delete(account: pin1Account)
    delete(account: pin2Account)
    #if os(macOS)
      OfferedAccessNumber.withdraw()
      DriverConfiguredCredentials.withdraw()
    #endif
  }
}
