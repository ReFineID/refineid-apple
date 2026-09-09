// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Why a test pairing did not produce a record.
internal enum SignRelayPairingFailure: Error {
  case closed(String)
  case endedWithoutRecord
}
