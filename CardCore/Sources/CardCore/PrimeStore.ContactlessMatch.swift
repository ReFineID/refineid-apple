// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension PrimeStore {
  /// A contactless lookup result and the field purpose it represents.
  public struct ContactlessMatch: Sendable {
    /// The identity metadata to publish.
    public let identity: PrimedIdentity

    /// True only for the app's one-time registration field.
    ///
    /// The token extension must publish without taking a card session in
    /// this field. Later signing fields take and retain the session.
    public let isRegistrationField: Bool

    /// Creates a contactless match pairing an identity with its field mark.
    public init(identity: PrimedIdentity, isRegistrationField: Bool) {
      self.identity = identity
      self.isRegistrationField = isRegistrationField
    }
  }
}
