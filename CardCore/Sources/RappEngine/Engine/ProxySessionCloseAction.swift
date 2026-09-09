// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// How an operation is classified when its session closes.
internal enum ProxySessionCloseAction: Equatable {
  /// Nothing was transmitted, so the operation is cancelled outright.
  case cancelled(operationIdentifier: Data)
  /// The card exchange is under way and finishes locally.
  case continueCardExchange(operationIdentifier: Data)
  /// A result exists but was never acknowledged.
  case deliveryUncertain(operationIdentifier: Data)
}
