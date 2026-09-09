// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The signed bytes and the validation level actually completed.
extension DocumentSigner {
  /// One completed document-signing operation.
  internal struct Product: Sendable {
    /// The finished PDF bytes.
    internal let bytes: Data

    /// The evidence level present in those bytes.
    internal let completion: Completion
  }

  /// What evidence was completed after the card signature.
  internal enum Completion: Equatable, Sendable {
    /// Complete PAdES-B-LTA evidence.
    case archival

    #if DEBUG
      /// Debug-only PAdES-B-T output from an authenticated revoked signer.
      case revokedSignerTest
    #endif
  }
}
