// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD

  import Foundation
  import Observation

  /// PIN 1 accepted for a card in a connected reader.
  ///
  /// Held only while that reader still has a card. The first live request
  /// stores the PIN. Disconnecting the reader or the card forgets it.
  /// NFC Enable still writes the durable store; this does not.
  @MainActor
  @Observable
  internal final class ReaderPin1Cache {
    internal static let shared = ReaderPin1Cache()

    private var digits: String?

    internal var isCached: Bool { digits != nil }

    private init() {
      // singleton
    }

    internal func current() -> String? { digits }

    internal func remember(_ pin1: String) {
      guard !pin1.isEmpty else {
        clear()
        return
      }
      digits = pin1
    }

    internal func clear() {
      digits = nil
    }
  }

#endif
