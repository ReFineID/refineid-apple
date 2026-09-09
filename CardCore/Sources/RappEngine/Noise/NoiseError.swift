// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Why a Noise operation could not be carried out.
internal enum NoiseError: Error {
  case handshakeIncomplete
  case malformedMessage
  case missingKeyMaterial
  case nonEmptyPayload
  case wrongTurn
}
