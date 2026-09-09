// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Why a received frame could not be turned into a message.
///
/// The two cases carry different consequences, so they are never merged: a
/// frame that fails to decrypt cannot be attributed to the paired peer, while
/// one that decrypts and then breaks the protocol can.
internal enum RappOpenFailure: Error, Equatable {
  /// Decrypted, then nonconforming. The pairing ends.
  case authenticatedProtocolViolation

  /// Not attributable to the peer. Close this session and nothing more.
  case sessionIntegrityFailure
}
