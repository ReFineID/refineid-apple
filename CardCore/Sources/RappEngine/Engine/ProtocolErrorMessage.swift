// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Registered protocol-level error names.
///
/// The registry is closed: an endpoint answers with one of these names or it
/// answers nothing. `busy` refuses a second concurrent operation without
/// changing state, and `unknown_operation` answers a stale reference.
internal enum ProtocolErrorMessage: Equatable {
  case busy
  case unknownOperation(operationIdentifier: Data?)

  internal var name: String {
    switch self {
    case .busy:
      EngineErrorName.busy

    case .unknownOperation:
      EngineErrorName.unknownOperation
    }
  }
}
