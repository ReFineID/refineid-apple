// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Why a binary read failed.
///
/// Unknown card behavior stays typed instead of degrading into a
/// partial result.
public enum BinaryReadFailure: Equatable, Sendable {
  /// The file produced no bytes at all.
  case emptyFile

  /// The object's own header declares more bytes than this read permits.
  case objectTooLarge

  /// The card returned more bytes than the chunk requested - a protocol
  /// violation; the accumulated data cannot be trusted.
  case oversizedChunk

  /// The card answered something other than success or end-of-file.
  case unexpectedStatus(StatusWord)
}
