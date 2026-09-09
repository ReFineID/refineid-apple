// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// One endpoint's long-lived pairing key pair.
internal struct PairKeyMaterial {
  internal let privateKey: Data
  internal let publicKey: Data

  /// A fresh pair key, generated for one pairing attempt.
  internal init() {
    let key = Curve25519.KeyAgreement.PrivateKey()
    privateKey = key.rawRepresentation
    publicKey = key.publicKey.rawRepresentation
  }

  /// The stored key of an existing pairing.
  internal init(privateKey: Data, publicKey: Data) {
    self.privateKey = privateKey
    self.publicKey = publicKey
  }
}
