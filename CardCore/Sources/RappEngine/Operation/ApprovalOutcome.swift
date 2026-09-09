// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What approving a request leads to, decided by whether the action is
/// consequential.
internal enum ApprovalOutcome: Equatable {
  case executeSafeRead(AuthorizedSafeRead)
  case prepared(OperationReference)
}
