// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// One side-effect-free reading of all three retry counters.
public struct CredentialRetryState: Equatable, Sendable {
  /// Attempts remaining for PIN1.
  public let pin1: RetryCount

  /// Attempts remaining for PIN2.
  public let pin2: RetryCount

  /// Attempts remaining for the PUK.
  public let puk: RetryCount

  /// Groups one simultaneous reading of the three counters.
  public init(pin1: RetryCount, pin2: RetryCount, puk: RetryCount) {
    self.pin1 = pin1
    self.pin2 = pin2
    self.puk = puk
  }
}
