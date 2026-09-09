// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(MultipeerConnectivity)
  @preconcurrency import MultipeerConnectivity
  import os

  /// Why the channel ended without an answer.
  public enum PersistentRelayTransportError: Error, Sendable {
    case cancelled
    case codec(String)
    case disconnected
    case send(String)
    case startup(String)
    case timedOut
  }
#endif
