// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What the BLE channel reports to its owner.
public enum BleRelayEvent: Sendable {
  case closed(BleRelayTransportError)
  case connected
  case frame(Data)
}
