// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension OperationResultMessage {
  /// A completed result carrying its typed output.
  internal static func completed(
    reference: OperationReference, result: CardOperationResult
  ) -> OperationResultMessage {
    OperationResultMessage(
      operationIdentifier: reference.operationIdentifier,
      requestHash: reference.requestHash,
      status: .completed,
      error: nil,
      result: result)
  }

  /// A non-successful result named from the stable registry.
  ///
  /// No free text enters the protocol: a failure is one of the registered
  /// names and nothing else.
  internal static func failure(
    reference: OperationReference, error: ResultError
  ) -> OperationResultMessage {
    OperationResultMessage(
      operationIdentifier: reference.operationIdentifier,
      requestHash: reference.requestHash,
      status: error.status,
      error: error,
      result: nil)
  }

  /// Checks the hash binding and that a completed body answers the operation
  /// it claims to answer.
  internal func validate(
    for reference: OperationReference, operation: CardOperation
  ) throws {
    guard operationIdentifier == reference.operationIdentifier,
      requestHash == reference.requestHash
    else { throw CardOperationError.requestHashMismatch }
    switch (status, error, result) {
    case (.completed, .none, .some(let result)):
      guard result.answers(operation) else { throw CardOperationError.profileActionMismatch }

    case (let status, .some(let error), .none):
      guard status != .completed, error.status == status else {
        throw CardOperationError.invalidField(field: "error")
      }

    default:
      throw CardOperationError.invalidField(field: "result")
    }
  }
}
