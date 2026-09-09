// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

// The case names are the ones the interface has always used and callers
// already catch by name.
// swiftlint:disable identifier_name sorted_enum_cases
// swift-format-ignore: AlwaysUseLowerCamelCase

/// A failure reported by the caller's storage.
///
/// Deliberately free of backend strings and secrets: the engine never
/// inspects storage itself, so these are the only ways a vault may refuse.
public enum RappVaultError: Error, Equatable, Hashable, LocalizedError, Sendable {
  /// Storage was unavailable or rejected the atomic operation.
  case Unavailable
  /// The identifier already names a stored record.
  case IdentifierAlreadyUsed
  /// No stored record carries the identifier.
  case PairNotFound

  /// The case name, for a caller that logs or displays the failure.
  public var errorDescription: String? {
    String(reflecting: self)
  }
}

// swiftlint:enable identifier_name sorted_enum_cases
