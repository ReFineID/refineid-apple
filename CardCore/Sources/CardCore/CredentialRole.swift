// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The credential a retry counter or PIN command refers to.
///
/// Distinct roles are never interchangeable: PIN2 has its own rules (never
/// cached), and the PUK is not a PIN.
public enum CredentialRole: CaseIterable, Equatable, Sendable {
  case pin1
  case pin2
  case puk
}
