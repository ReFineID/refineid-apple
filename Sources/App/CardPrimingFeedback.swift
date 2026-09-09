// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  import AudioToolbox
  import UIKit

  /// Says out loud that a hold is running, and how it ended.
  ///
  /// The system NFC sheet cannot: `TKSmartCardSlotNFCSession` carries a
  /// message and `endSession` and nothing else, so it dismisses with the
  /// same checkmark whether the hold registered an identity or died at
  /// PACE. A holder is also looking at the card rather than the screen
  /// for the several seconds a hold takes, which is exactly when they
  /// most need to know it is still working.
  ///
  /// So there are three sounds and they mean three different things:
  /// the provisioning tone repeating for as long as the card is being
  /// read, the card-provisioned pling when an identity is registered,
  /// and the card-error tone when one is not. The repeating tone is what
  /// makes the two outcomes legible -- it stops, and what replaces it is
  /// the answer.
  ///
  /// All three are the sounds iOS itself uses while provisioning a card,
  /// taken from the system sound library by name (``UISoundLibrary``),
  /// because that is exactly what a hold is doing. Haptics are
  /// `UINotificationFeedbackGenerator`, likewise the system's own.
  ///
  /// Both obey the phone's switches: a silenced phone plays nothing, and
  /// a phone with system haptics off feels nothing. The haptic is why
  /// there are two channels -- it still fires on a silenced phone, so a
  /// failed hold is never completely quiet.
  @MainActor
  internal enum CardPrimingFeedback {
    /// The repeating tick, running while the hold is.
    private static var ticking: Task<Void, Never>?

    /// The tone iOS plays while a card is being provisioned.
    ///
    /// A 2.6-second phrase rather than a tick, and the right one by
    /// meaning: setting an identity up IS provisioning a card. It is
    /// replayed end to end for as long as the hold runs.
    private static let workingSoundName = "NFCCardProvisioned"

    /// The pling iOS plays when a card finishes provisioning.
    ///
    /// The sound the holder already knows means the card is now set up.
    private static let successSoundName = "NFCCardComplete"

    /// The tone iOS plays when a card does not provision.
    ///
    /// The whole point of this one: it is the system's own sound for a
    /// card that did not work, so it reaches a holder who has already
    /// looked away and been shown Apple's checkmark.
    private static let failureSoundName = "NFCCardError"

    /// The keyboard tock, if the provisioning tone is not on this
    /// system.
    private static let workingFallbackID: SystemSoundID = 1_104

    /// The bright tink, if the NFC pling is not on this system.
    private static let successFallbackID: SystemSoundID = 1_057

    /// The blunt alert tone, if the NFC failure tone is not.
    private static let failureFallbackID: SystemSoundID = 1_073

    /// How long one working phrase runs, in milliseconds.
    ///
    /// `NFCCardProvisioned` is 2.61 seconds long, so it is replayed just
    /// after it ends: sooner and two copies overlap into a stutter,
    /// later and the hold falls silent in the middle.
    private static let workingMilliseconds: Int = 2_650

    /// That length as the sleep takes it.
    private static let workingInterval: Duration = .milliseconds(Self.workingMilliseconds)

    /// How many phrases the tone may play before stopping itself.
    ///
    /// A backstop, not a schedule: the hold normally ends this sound by
    /// finishing. But a sound that outlives its reason is worse than no
    /// sound at all -- it says a hold is running when none is -- so it
    /// gets an end of its own. Twelve phrases is about thirty seconds,
    /// longer than the arrival budget and every hold measured on device.
    private static let workingRepeatLimit: Int = 12

    /// Starts the tick that says the hold is still running.
    ///
    /// Safe to call twice: a second start replaces the first rather than
    /// layering a second tick over it.
    internal static func startWorking() {
      Self.stopWorking()
      Self.ticking = Task { @MainActor in
        for _ in 1...Self.workingRepeatLimit where !Task.isCancelled {
          AudioServicesPlaySystemSound(
            UISoundLibrary.soundID(
              named: Self.workingSoundName, fallback: Self.workingFallbackID))
          try? await Task.sleep(for: Self.workingInterval)
        }
      }
    }

    /// Stops the tick and reports the outcome, by sound and by haptic.
    ///
    /// Both channels, because either alone is missable: a phone in a
    /// pocket is felt and not heard, one on a desk is heard and not
    /// felt.
    internal static func report(succeeded: Bool) {
      Self.stopWorking()
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(succeeded ? .success : .error)
      AudioServicesPlaySystemSound(
        succeeded
          ? UISoundLibrary.soundID(
            named: Self.successSoundName, fallback: Self.successFallbackID)
          : UISoundLibrary.soundID(
            named: Self.failureSoundName, fallback: Self.failureFallbackID))
    }

    /// Ends the tick without saying anything about the outcome.
    internal static func stopWorking() {
      Self.ticking?.cancel()
      Self.ticking = nil
    }
  }

#endif
