// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  import Foundation

  /// Keeps the running step states and repaints the NFC sheet from them.
  ///
  /// Every step change and every sentence go through here, so the sheet
  /// always shows the whole meter rather than whichever half was written
  /// most recently. The card work runs on its own queue and the steps
  /// are reported from there, so the states live behind a lock.
  ///
  /// `@unchecked Sendable` is the audit: the dictionary is touched only
  /// under the lock, and the session it draws into is itself safe to
  /// update from any thread.
  internal final class PrimingSheetReporter: @unchecked Sendable {
    /// The hold this meter is drawn on, so a caller needing the card
    /// does not have to be handed the session separately.
    internal let session: NearFieldCardSession

    private let lock = NSLock()
    private var states: [CardPrimingStep: CardPrimingStep.State] = [:]

    internal init(session: NearFieldCardSession) {
      self.session = session
    }

    /// Records a step's state and repaints the meter.
    internal func report(_ step: CardPrimingStep, _ state: CardPrimingStep.State) {
      lock.lock()
      states[step] = state
      let snapshot = states
      lock.unlock()
      session.update(message: PrimingSheetMessage.meter(states: snapshot))
    }

    /// Replaces the whole message with why the hold stopped.
    ///
    /// The meter goes when this is called, and deliberately: the panel
    /// truncates anything past its line, so a meter and a reason
    /// together cost the reason. A hold that is about to dismiss has one
    /// thing left to say and it is not how far it got.
    internal func fail(_ sentence: String) {
      session.update(message: sentence)
    }
  }

#endif
