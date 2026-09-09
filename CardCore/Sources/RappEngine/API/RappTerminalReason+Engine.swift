// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Translations between the public vocabulary and the engine's own.
///
/// The public names are the ones callers already wrote against, so they are
/// kept even where the engine spells a value differently.
extension RappTerminalReason {
  internal init(_ error: ResultError) {
    switch error {
    case .userDenied:
      self = .userDenied

    case .requestExpired:
      self = .requestExpired

    case .cancelled:
      self = .cancelled

    case .requestInvalidOrUnsupported:
      self = .requestInvalidOrUnsupported

    case .retryPolicyRefused:
      self = .retryPolicyRefused

    case .credentialRejected:
      self = .credentialRejected

    case .cardRemovedBeforeTransmit:
      self = .cardRemovedBeforeTransmit

    case .cardCompletionAmbiguous:
      self = .cardCompletionAmbiguous
    }
  }
}
