// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(MultipeerConnectivity)
  @preconcurrency import MultipeerConnectivity
  import os

  /// Which side of the relay this process plays.
  public enum PersistentRelayRole: Sendable {
    case cardHolder
    case host
  }
#endif
