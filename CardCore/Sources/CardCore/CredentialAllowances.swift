// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// One credential's two allowances, as the card reports them.
public struct CredentialAllowances: Equatable, Sendable {
  /// How many times the credential itself may still be presented
  /// successfully.
  public let usages: CredentialAllowance

  /// How many times it may still unblock something.
  ///
  /// Only meaningful for the PUK, and the number that decides whether
  /// a PUK survives being used.
  public let unblockings: CredentialAllowance

  /// Groups one reading.
  public init(usages: CredentialAllowance, unblockings: CredentialAllowance) {
    self.usages = usages
    self.unblockings = unblockings
  }
}
