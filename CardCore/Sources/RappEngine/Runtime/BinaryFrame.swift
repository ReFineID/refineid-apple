// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One bounded transport frame.
///
/// The bound is checked on construction, so a frame that exists is a frame
/// the protocol admits and no later stage repeats the test.
internal struct BinaryFrame: Equatable {
  private let payload: Data

  internal var bytes: Data { payload }

  internal var count: Int { payload.count }

  /// Takes ownership of frame bytes after checking the wire limit.
  internal init(reconstructing bytes: Data) throws {
    guard bytes.count <= RappFrameLimits.maximumFrame else {
      throw RappFrameError.oversized(got: bytes.count, maximum: RappFrameLimits.maximumFrame)
    }
    payload = bytes
  }
}
