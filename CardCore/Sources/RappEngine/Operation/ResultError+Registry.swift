// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension ResultError {
  /// The one status this failure name belongs to.
  ///
  /// The pairing is fixed by the registry, so a result cannot name a failure
  /// that contradicts its own status.
  internal var status: ResultStatus {
    switch self {
    case .userDenied:
      .denied

    case .requestExpired, .cancelled, .cardRemovedBeforeTransmit:
      .cancelled

    case .requestInvalidOrUnsupported, .retryPolicyRefused:
      .rejected

    case .credentialRejected:
      .credentialRejected

    case .cardCompletionAmbiguous:
      .ambiguous
    }
  }
}
