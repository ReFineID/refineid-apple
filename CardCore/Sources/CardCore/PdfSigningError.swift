// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// Why a PDF could not be prepared or signed.
public enum PdfSigningError: Error, Equatable {
  /// A cross-reference or object stream uses a filter or predictor
  /// this reader does not decode.
  case crossReferenceStreamUnsupported

  /// The document is encrypted; this writer will not touch it.
  case encrypted

  /// The bytes do not begin as a PDF.
  case notAPdf

  /// The assembled structure outgrew its reserved hole; the hole
  /// cannot be resized after the byte ranges are fixed.
  case signatureTooLarge(needed: Int, reserved: Int)

  /// The catalog, page tree or trailer could not be followed.
  case structureUnreadable
}
