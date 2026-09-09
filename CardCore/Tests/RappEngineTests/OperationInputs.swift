// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The values fixed when the operation bodies were captured, recorded beside
/// them so the Swift engine builds from identical inputs.
internal struct OperationInputs: Decodable {
  private enum CodingKeys: String, CodingKey {
    case operationIdentifierRequest = "operation_id_request"
    case operationIdentifierReference = "operation_id_reference"
    case operationIdentifierStatus = "operation_id_status"
    case operationIdentifierError = "operation_id_error"
    case requestHashReference = "request_hash_reference"
    case requestHashStatus = "request_hash_status"
    case pairIdentifier = "pair_id"
    case sessionIdentifier = "session_id"
    case digestSha256 = "digest_sha256"
    case digestSha384 = "digest_sha384"
    case signatureBytes = "signature_bytes"
    case certificateDer = "certificate_der"
    case origin = "origin"
    case documentName = "document_name"
    case displayName = "display_name"
    case personIdentifier = "person_id"
    case cancelReason = "cancel_reason"
    case localStartMilliseconds = "local_start_ms"
    case expiresAfterMilliseconds = "expires_after_ms"
    case inspection = "inspection"
  }

  internal let operationIdentifierRequest: String
  internal let operationIdentifierReference: String
  internal let operationIdentifierStatus: String
  internal let operationIdentifierError: String
  internal let requestHashReference: String
  internal let requestHashStatus: String
  internal let pairIdentifier: String
  internal let sessionIdentifier: String
  internal let digestSha256: String
  internal let digestSha384: String
  internal let signatureBytes: String
  internal let certificateDer: String
  internal let origin: String
  internal let documentName: String
  internal let displayName: String
  internal let personIdentifier: String
  internal let cancelReason: String
  internal let localStartMilliseconds: UInt64
  internal let expiresAfterMilliseconds: UInt64
  internal let inspection: OperationInspectionInput
}
