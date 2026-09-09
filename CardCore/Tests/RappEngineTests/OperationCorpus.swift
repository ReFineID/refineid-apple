// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The vendored operation-protocol message bodies.
internal struct OperationCorpus: Decodable {
  private enum CodingKeys: String, CodingKey {
    case format = "format"
    case protocolDocumentVersion = "protocol_document_version"
    case fixedInputs = "fixed_inputs"
    case vectors = "vectors"
  }

  internal let format: String
  internal let protocolDocumentVersion: String
  internal let fixedInputs: OperationInputs
  internal let vectors: [OperationVector]
}
