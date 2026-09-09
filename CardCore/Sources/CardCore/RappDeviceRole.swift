// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Defines the operational role of a device in RAPP.
public enum RappDeviceRole: String, Codable, Sendable {
  /// Holds the physical card (e.g. iPhone) and answers APDU requests.
  case holder = "holder"
  /// Requests smartcard operations (e.g. Mac, iPad) and borrows identity.
  case requester = "requester"
}
