// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import SwiftUI

/// The holder's transport choice, as the settings UI sees it.
///
/// Writes go straight to `CardTransportStore` so the token extension --
/// a separate process -- observes the same choice. The published value
/// is always clamped to what the platform supports, so a preference
/// carried over from another device can never present a control the
/// hardware cannot honour.
@MainActor
internal final class TransportPreferences: ObservableObject {
  /// The transports this device could offer.
  internal let supported: CardTransportSelection

  /// The transports the holder currently allows.
  @Published internal private(set) var selection: CardTransportSelection

  /// Set when the last change could not be stored, so the UI can say so
  /// rather than silently showing a value that did not stick.
  @Published internal private(set) var lastWriteFailed = false

  internal init() {
    let platformCeiling = SupportedCardTransports.current
    supported = platformCeiling
    selection = CardTransportStore.load().clamped(to: platformCeiling)
  }

  /// Whether the holder allows this transport right now.
  internal func permits(_ transport: CardTransport) -> Bool {
    selection.permits(transport)
  }

  /// Turns one transport on or off.
  ///
  /// Turning off the last enabled transport is refused: an app with no
  /// way to reach a card cannot do anything useful, and the refusal
  /// belongs here, next to the control, rather than as a failure later.
  internal func setPermitted(_ isPermitted: Bool, for transport: CardTransport) {
    let updated: CardTransportSelection? =
      isPermitted
      ? selection.enabling(transport)
      : selection.disabling(transport)
    guard let updated, updated != selection else {
      lastWriteFailed = !isPermitted
      return
    }
    selection = updated
    lastWriteFailed = !CardTransportStore.save(updated)
  }
}
