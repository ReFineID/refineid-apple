// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import AppKit
  import Foundation
  import Observation

  /// A brief memory of a PIN 2 that a signature accepted, so a pile of
  /// documents signs with one entry.
  ///
  /// Only a PIN a signature just accepted is ever remembered, so a
  /// remembered value can never spend a wrong-PIN attempt against the
  /// card - it is known good. It lives one minute and is dropped the
  /// moment the card leaves, the app steps to the background, a
  /// signature fails, or the minute is up, whichever comes first.
  ///
  /// The digits are held as bytes this owns and overwrites on release,
  /// rather than a `String` that cannot be overwritten in place. The
  /// PIN still reaches here as the `String` the field delivered, so the
  /// zeroization covers this store's own copy, not every copy the PIN
  /// ever had.
  @MainActor
  @Observable
  internal final class Pin2Cache {
    /// How long a verified PIN 2 is remembered.
    private static let lifetimeSeconds = 60

    /// The remembered digits, overwritten when released.
    @ObservationIgnored private var digits: [UInt8] = []

    /// When the memory expires, or nil when nothing is remembered.
    private var expiry: Date?

    /// The expiry timer, cancelled when a new PIN replaces this one.
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    /// The background-clearing subscription, held for the cache's life.
    @ObservationIgnored private var resignObserver: NSObjectProtocol?

    /// Whether a PIN 2 is remembered right now.
    internal var isWarm: Bool {
      guard let expiry else { return false }
      return expiry > Date()
    }

    internal init() {
      // Stepping away forgets the PIN: a signing app left in the
      // background must not hold one ready for whoever returns to the
      // Mac. The cache owns this rather than the window, so no window
      // has to remember to.
      resignObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.clear() }
      }
    }

    /// The remembered PIN 2, or nil when nothing valid is held.
    internal func current() -> String? {
      guard isWarm, !digits.isEmpty else { return nil }
      return String(bytes: digits, encoding: .utf8)
    }

    /// Remembers a PIN 2 a signature just accepted, replacing any
    /// earlier one and restarting the minute.
    internal func remember(_ pin2: String) {
      zero()
      digits = Array(pin2.utf8)
      expiry = Date().addingTimeInterval(TimeInterval(Self.lifetimeSeconds))
      expiryTask?.cancel()
      expiryTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(Self.lifetimeSeconds))
        guard !Task.isCancelled else { return }
        self?.clear()
      }
    }

    /// Forgets the PIN 2 now, overwriting the digits.
    internal func clear() {
      expiryTask?.cancel()
      expiryTask = nil
      zero()
      expiry = nil
    }

    /// Overwrites and empties the held digits.
    private func zero() {
      for index in digits.indices {
        digits[index] = 0
      }
      digits = []
    }
  }

#endif
