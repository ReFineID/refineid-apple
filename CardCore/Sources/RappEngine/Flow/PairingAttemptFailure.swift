// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// A candidate attempt that failed before any pairing was stored, carrying the
/// still-live offer so another candidate may reuse it.
///
/// The offer is deliberately not printable: it holds the one-use secret.
internal struct PairingAttemptFailure: Error {
  internal let error: PairingError
  internal let offer: PairingOffer
}
