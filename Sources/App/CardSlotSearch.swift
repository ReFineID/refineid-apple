// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoTokenKit

/// Finds the slot a card is actually in.
///
/// "The first slot" is not the card's slot. A dual-interface reader
/// publishes its contact, contactless and SAM interfaces as three slots
/// whose names differ only by a trailing index, and the order they are
/// named in is not the order they are used in. Taking the first name is
/// how a card resting on the antenna came to be reported as an empty
/// reader on the status screen, and how a probe answered "no reader or
/// card" about a card that was signing for Safari at the time.
internal enum CardSlotSearch {
  /// The first slot holding a card, with the name it is known by.
  internal static func occupied(
    in manager: TKSmartCardSlotManager
  ) async -> (name: String, slot: TKSmartCardSlot)? {
    await allOccupied(in: manager).first
  }

  /// Every slot holding a card, in the system's naming order.
  ///
  /// A dual-interface reader can present one physical card on both
  /// its contact and contactless slots at once - the antenna reads
  /// through the housing. Which of the two enumerates first is not
  /// stable, and only one of them is usable without PACE, so a
  /// caller that needs a working session must be free to try each.
  internal static func allOccupied(
    in manager: TKSmartCardSlotManager
  ) async -> [(name: String, slot: TKSmartCardSlot)] {
    var found: [(name: String, slot: TKSmartCardSlot)] = []
    for name in manager.slotNames {
      if let slot = await manager.getSlot(withName: name), slot.state == .validCard {
        found.append((name, slot))
      }
    }
    return found
  }

  /// The slot worth naming on screen: the one holding a card, else the
  /// first the system names, so an empty reader still has a name.
  internal static func nameToReportOn(in manager: TKSmartCardSlotManager) async -> String? {
    await occupied(in: manager)?.name ?? manager.slotNames.first
  }
}
