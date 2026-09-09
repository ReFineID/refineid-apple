// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(MultipeerConnectivity) && canImport(RappEngine)
  import Foundation
  import RappEngine

  /// A card operation the requester asks the paired proxy to perform.
  public enum RappRequesterOperation: Sendable, Equatable {
    case browserAuthentication(
      displayContext: String,
      keyProfile: RappOperationDriver.KeyProfile,
      algorithm: RappOperationDriver.SignatureAlgorithm,
      digest: Data
    )
    case documentSigning(
      documentName: String,
      keyProfile: RappOperationDriver.KeyProfile,
      algorithm: RappOperationDriver.SignatureAlgorithm,
      digest: Data
    )
    case readAuthenticationCertificate
    case readSignatureCertificate
  }
#endif
