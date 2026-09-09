// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One holder's approval of one exact request.
///
/// The approval carries the request hash, so it authorizes that request and
/// no other. Moving it to a different request fails the comparison.
internal struct UserApproval: Equatable {
  internal let operationIdentifier: Data
  internal let requestHash: Data
  internal let approvedAtMilliseconds: UInt64

  internal init(for request: OperationRequest, approvedAtMilliseconds: UInt64) throws {
    self.operationIdentifier = request.operationIdentifier
    self.requestHash = try request.requestHash()
    self.approvedAtMilliseconds = approvedAtMilliseconds
  }
}
