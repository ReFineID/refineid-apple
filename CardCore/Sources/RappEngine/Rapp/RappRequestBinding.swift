// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Everything one typed request binds itself to when it is hashed.
internal struct RappRequestBinding {
  internal let sessionIdentifier: Data
  internal let operationIdentifier: Data
  internal let profile: String
  internal let action: String
  internal let context: [String: WireValue]
  internal let payload: [String: WireValue]
}
