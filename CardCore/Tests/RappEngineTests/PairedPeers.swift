// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// One completed pairing, as both peers ended up holding it.
internal struct PairedPeers {
  internal let requester: PairRecord
  internal let proxy: PairRecord
  internal let requesterPairIdentifier: Data
  internal let proxyPairIdentifier: Data
}
