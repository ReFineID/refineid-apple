// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A physical way of reaching the card.
///
/// The two transports differ in cost rather than capability. A reader is
/// passive, enumerable, and needs no card access number; the phone
/// antenna needs no hardware but seals the card's application until PACE
/// has run, so it asks the holder for a CAN and for several seconds of
/// stillness.
///
/// Raw values are persisted in the transport preference and must stay
/// stable across releases.
public enum CardTransport: String, CaseIterable, Equatable, Sendable {
  /// The phone's own antenna: contactless, iOS 26 and later only.
  ///
  /// macOS has no NFC smart-card slot at all, so this case is never
  /// supported there.
  case nearField = "near-field"

  /// A contact reader over USB, USB-C, or the platform's PC/SC stack.
  case reader = "reader"

  /// What the system calls the phone's own contactless slot.
  ///
  /// `TKSmartCardSlotManager.createNFCSlot` names the slot it opens
  /// "Built-in NFC Slot"; a reader slot carries the reader's own name.
  /// The name is all there is to classify a slot by before any card
  /// I/O, and both the token extension and the app have to reach the
  /// same verdict about the same slot, so the marker lives here rather
  /// than once in each of them.
  public static let nearFieldSlotMarker = "Built-in NFC Slot"

  /// Which transport a slot of this name belongs to.
  public static func transport(forSlotNamed name: String) -> Self {
    name.localizedCaseInsensitiveCompare(Self.nearFieldSlotMarker) == .orderedSame
      ? .nearField
      : .reader
  }
}
