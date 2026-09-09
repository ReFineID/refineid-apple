// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What the stream channel reports to its one owner.
public enum StreamRelayEvent: Sendable {
  case closed(StreamRelayTransportError)
  case connected
  case frame(Data)
}
