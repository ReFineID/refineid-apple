// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What one card carries, certificate by certificate, with the key
/// each belongs to.
public enum Pkcs15Inventory {
  /// One certificate and, when the card lists a key sharing its
  /// identifier, that key.
  public struct Entry: Equatable, Sendable {
    /// The certificate the card lists.
    public let certificate: Pkcs15Directory.Certificate

    /// The key that signs for it, absent for an authority certificate
    /// the card carries without a key.
    public let key: Pkcs15Directory.PrivateKey?
  }

  /// Pairs each certificate with the key carrying the same identifier.
  public static func pair(
    certificates: [Pkcs15Directory.Certificate],
    keys: [Pkcs15Directory.PrivateKey]
  ) -> [Entry] {
    certificates.map { certificate in
      Entry(
        certificate: certificate,
        key: keys.first { $0.identifier == certificate.identifier })
    }
  }
}
