// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What a binary read needs next.
public enum BinaryReadStep: Equatable, Sendable {
  /// The read finished; the accumulated file content.
  case complete(Data)

  /// The read cannot finish; the typed reason.
  case failed(BinaryReadFailure)

  /// Send this command and feed the response back to the assembler.
  case transmit(CommandApdu)
}
