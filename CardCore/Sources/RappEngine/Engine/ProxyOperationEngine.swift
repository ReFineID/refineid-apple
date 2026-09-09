// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Operations for one authenticated proxy session.
///
/// Exactly one operation may be live. The engine holds the granted profiles
/// authenticated by the pairing transcript, so a request naming any other
/// profile is refused before the holder is ever asked.
internal struct ProxyOperationEngine {
  internal let grantedProfiles: [ProfileName]

  internal var operations: [AuthorizationTransaction]

  internal var recovered: [RecoveredProxyRecord]

  /// The live operations, for tests and for status answers.
  internal var liveOperationStates: [Data: OperationState] {
    var states: [Data: OperationState] = [:]
    for operation in operations {
      states[operation.reference.operationIdentifier] = operation.operationState
    }
    return states
  }

  /// An engine bound to exactly the profiles the pairing granted.
  ///
  /// An empty grant set deliberately admits no operation at all.
  internal init(grantedProfiles: [ProfileName], recovered: [RecoveredProxyRecord]) {
    self.grantedProfiles = grantedProfiles
    self.operations = []
    self.recovered = recovered
  }
}
