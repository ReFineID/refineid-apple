// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if REFINEID_LOCAL_CARD && os(iOS)

  import SwiftUI

  /// What a successful setup hold is allowed to write, and where.
  ///
  /// Gathered into one value because they are one decision: nothing the
  /// holder typed reaches this device until the card has proved the access
  /// number and the identity is registered, so the writes travel together
  /// with the clearing that follows them.
  @MainActor
  internal struct IdentityCommitments {
    /// Commits the access number once PACE has proved it.
    internal let storeCardAccessNumber: (String) -> Bool

    /// Commits PIN1 once the identity it belongs to exists.
    internal let storeVerifiedPin1: (String) -> Bool

    /// Empties the transient entry, whatever the hold decided.
    internal let clearPin1Entry: () -> Void

    /// Records that this device now has an identity.
    internal let markRegistered: () -> Void
  }

#endif
