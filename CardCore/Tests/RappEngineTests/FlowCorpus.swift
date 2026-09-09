// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The vendored pairing and session message bodies.
internal struct FlowCorpus: Decodable {
  private enum CodingKeys: String, CodingKey {
    case format = "format"
    case protocolDocumentVersion = "protocol_document_version"
    case fixedInputs = "fixed_inputs"
    case flowMessage = "flow_message"
  }

  internal let format: String
  internal let protocolDocumentVersion: String
  internal let fixedInputs: FlowInputs
  internal let flowMessage: [FlowVector]
}
