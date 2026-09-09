// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// The cases are transcribed in the order the formal model lists them, so the
// tables read line for line against the document. Alphabetising them would
// break the correspondence the bidirectional conformance test protects.
// swiftlint:disable sorted_enum_cases

/// The endpoint's role in a pairing.
///
/// Every rule in the formal model names the role or roles that implement it,
/// so an endpoint runs exactly the projection belonging to it.
internal enum EndpointRole: String, CaseIterable, Sendable {
  case requester = "requester"
  case proxy = "proxy"
}

// swiftlint:enable sorted_enum_cases
