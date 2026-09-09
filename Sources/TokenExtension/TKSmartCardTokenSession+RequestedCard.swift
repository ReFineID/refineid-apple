// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoTokenKit

extension TKSmartCardTokenSession {
  /// The card this request runs against, with its exclusive session already
  /// open and the application selected.
  internal func requestedSmartCard() throws -> TKSmartCard {
    try getSmartCard()
  }
}
