// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The complete response to one incident.
internal struct IncidentDisposition: Equatable, Sendable {
  internal let pairing: PairingDisposition
  internal let session: SessionDisposition
  internal let operation: OperationDisposition
  /// Whether further work needs a fresh explicit user action.
  internal let requiresNewUserIntent: Bool
}
