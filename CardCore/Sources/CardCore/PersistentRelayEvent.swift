// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(MultipeerConnectivity)
  @preconcurrency import MultipeerConnectivity
  import os

  /// What the channel reports to its one owner.
  public enum PersistentRelayEvent: Sendable {
    case closed(PersistentRelayTransportError)
    case connected
    case frame(Data)
  }
#endif
