// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import os

/// Process-lifetime memory of PINs a card has rejected.
///
/// A PIN the card rejected is never sent to that same card again for the
/// process lifetime: re-entering the identical wrong PIN must not burn a
/// second attempt. Because every fingerprint is bound to the full card
/// serial and role, a rejection on one card can never block a distinct
/// card, and a different PIN on the same card is unaffected.
///
/// The memory stores only non-reversible fingerprints - never a PIN.
public final class RejectedPinMemory: Sendable {
  private let rejected = OSAllocatedUnfairLock<Set<PinFingerprint>>(initialState: [])

  /// Creates an empty memory; the driver owns one per process.
  public init() {
    // Starts empty by definition: nothing has been rejected yet.
  }

  /// Records that the card bound into the fingerprint rejected this PIN.
  public func recordRejection(_ fingerprint: PinFingerprint) {
    rejected.withLock { set in
      // The insertion report is deliberately dropped: recording a
      // rejection twice is the same fact, not new information.
      _ = set.insert(fingerprint)
    }
  }

  /// True when this exact PIN was already rejected by the card bound into
  /// the fingerprint.
  ///
  /// The caller must refuse the operation without touching the card.
  public func isKnownRejected(_ fingerprint: PinFingerprint) -> Bool {
    rejected.withLock { set in
      set.contains(fingerprint)
    }
  }
}
