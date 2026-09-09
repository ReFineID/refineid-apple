// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Why the BLE transport ended or failed.
public enum BleRelayTransportError: Error, Equatable, Sendable {
  case bluetoothUnavailable
  case cancelled
  case disconnected
  case invalidFrameLength
  case malformedFrame
  case notConnected
  case send(String)
  case unreachable
}
