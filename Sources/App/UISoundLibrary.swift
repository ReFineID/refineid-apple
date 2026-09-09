// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) || os(macOS)

  import AudioToolbox
  import Foundation

  /// The system's own interface sounds, by the name of the file iOS
  /// keeps them in.
  ///
  /// The numbered `SystemSoundID` constants reach only a fraction of
  /// what the system actually has, and none of the NFC family: the tones
  /// a holder already associates with a card being read live in
  /// `/System/Library/Audio/UISounds` or `ToneLibrary` as named files.
  /// Registering one by URL gives back an ordinary sound id, so a card
  /// operation can sound the way every other card operation on the phone
  /// does rather than borrowing an unrelated beep.
  ///
  /// The directories are not API. A name that is not there on some future
  /// system resolves to the numbered tone the caller passes as its
  /// fallback, so a missing file costs the right sound and never the
  /// feedback itself.
  ///
  /// Ids are registered once and kept: `AudioServicesCreateSystemSoundID`
  /// allocates, and re-registering per play would leak one allocation per
  /// sound played.
  @MainActor
  internal enum UISoundLibrary {
    /// Directories where iOS and macOS keep interface and alert sounds.
    private static let searchDirectories: [String] = [
      "/System/Library/Audio/UISounds/",
      "/System/Library/PrivateFrameworks/ToneLibrary.framework/AlertTones/EncoreInfinitum/",
      "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/EncoreInfinitum/",
    ]

    /// The container every one of them is in.
    private static let fileExtension = "caf"

    /// Ids already registered this launch, by file name.
    private static var registered: [String: SystemSoundID] = [:]

    /// Standard fallback alert tone identifier when a named sound file is missing.
    internal static let defaultAlertFallbackID: SystemSoundID = 1_007

    /// The sound id for `name`, or `fallback` when this system has no
    /// such file.
    internal static func soundID(named name: String, fallback: SystemSoundID) -> SystemSoundID {
      if let known = Self.registered[name] {
        return known
      }
      for directory in Self.searchDirectories {
        let path = directory + name + "." + Self.fileExtension
        guard FileManager.default.fileExists(atPath: path) else { continue }
        let url = URL(fileURLWithPath: path)
        var created: SystemSoundID = 0
        if AudioServicesCreateSystemSoundID(url as CFURL, &created) == kAudioServicesNoError {
          Self.registered[name] = created
          return created
        }
      }
      Self.registered[name] = fallback
      return fallback
    }

    /// Plays the sound named `name`, falling back to `defaultAlertFallbackID` if unavailable.
    internal static func play(named name: String) {
      play(named: name, fallback: defaultAlertFallbackID)
    }

    /// Plays the sound named `name`, falling back to `fallback` if unavailable.
    internal static func play(named name: String, fallback: SystemSoundID) {
      AudioServicesPlaySystemSound(soundID(named: name, fallback: fallback))
    }
  }

#endif
