// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The signing seam behind the SCS protocol surface.
///
/// The dispatcher and the transaction flow are pure protocol logic;
/// everything that touches a card - certificates, key algorithms, the
/// PIN-gated sign itself - crosses this seam. The production backend
/// drives a card session; tests supply canned material so the whole
/// protocol surface is exercised without hardware.
public protocol ScsSigningBackend {
  /// The DER certificate chain for `purpose`, leaf first.
  func certificateChain(for purpose: ScsSignPurpose) -> [Data]

  /// The key algorithm behind `purpose`, for the response's
  /// `signatureAlgorithm` field.
  func keyAlgorithm(for purpose: ScsSignPurpose) -> ScsKeyAlgorithm

  /// Signs `data` with the `purpose` key after hashing it with
  /// `hash`. Throws `ScsBackendFailure` so the protocol layer can
  /// answer the specified reason code.
  func sign(purpose: ScsSignPurpose, hash: SigningHash, data: Data) throws -> Data
}
