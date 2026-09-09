// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the specification registers them,
// so the source reads line for line against the document.
// swiftlint:disable sorted_enum_cases

import Foundation

/// Credential profiles the registry admits.
internal enum ProfileName: String, CaseIterable, Equatable {
  case cardStatus = "fi.refineid.card-status.v1"
  case authentication = "fi.refineid.authentication.v1"
  case documentSigning = "fi.refineid.document-signing.v1"
}

// swiftlint:enable sorted_enum_cases
