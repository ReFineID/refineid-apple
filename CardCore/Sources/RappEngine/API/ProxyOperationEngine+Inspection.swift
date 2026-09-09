// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Read-only views of a live operation.
///
/// The interface layer must name the operation the holder is being asked
/// about, and must bind an approval to the exact request that was displayed.
/// Neither changes engine state.
extension ProxyOperationEngine {
  /// The live transaction the identifier names.
  private func transaction(_ operationIdentifier: Data) -> AuthorizationTransaction? {
    operations.first { $0.reference.operationIdentifier == operationIdentifier }
  }

  /// The request a live operation carries.
  internal func request(_ operationIdentifier: Data) -> OperationRequest? {
    transaction(operationIdentifier)?.request
  }

  /// What a live operation asks the card to do.
  internal func operation(_ operationIdentifier: Data) -> CardOperation? {
    transaction(operationIdentifier)?.request.operation
  }

  /// The reference naming a live operation and the request it answers.
  internal func reference(_ operationIdentifier: Data) -> OperationReference? {
    transaction(operationIdentifier)?.reference
  }
}
