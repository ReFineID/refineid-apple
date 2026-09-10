// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Security

extension TimestampCmsVerifier {
  // MARK: Nested Types

  /// Digest algorithms accepted for timestamp signatures.
  internal enum Digest: Equatable {
    case sha256
    case sha384
    case sha512

    // MARK: Computed Properties

    internal var byteCount: Int {
      switch self {
      case .sha256:
        SHA256.byteCount

      case .sha384:
        SHA384.byteCount

      case .sha512:
        SHA512.byteCount
      }
    }

    internal var ecdsaAlgorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .ecdsaSignatureMessageX962SHA256

      case .sha384:
        .ecdsaSignatureMessageX962SHA384

      case .sha512:
        .ecdsaSignatureMessageX962SHA512
      }
    }

    internal var rsaPkcs1Algorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .rsaSignatureMessagePKCS1v15SHA256

      case .sha384:
        .rsaSignatureMessagePKCS1v15SHA384

      case .sha512:
        .rsaSignatureMessagePKCS1v15SHA512
      }
    }

    internal var rsaPssAlgorithm: SecKeyAlgorithm {
      switch self {
      case .sha256:
        .rsaSignatureMessagePSSSHA256

      case .sha384:
        .rsaSignatureMessagePSSSHA384

      case .sha512:
        .rsaSignatureMessagePSSSHA512
      }
    }

    // MARK: Functions

    internal func hash(_ data: Data) -> Data {
      switch self {
      case .sha256:
        Data(SHA256.hash(data: data))

      case .sha384:
        Data(SHA384.hash(data: data))

      case .sha512:
        Data(SHA512.hash(data: data))
      }
    }
  }
}
