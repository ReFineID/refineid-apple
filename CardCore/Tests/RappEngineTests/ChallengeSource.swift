// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// Hands out distinct probe challenges; echo checks reuse the handed value.
internal struct ChallengeSource {
  private var nextByte: UInt8 = 1

  internal mutating func next() -> PingChallenge {
    defer { nextByte += 1 }
    return challenge(nextByte)
  }
}
