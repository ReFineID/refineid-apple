// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import RappEngine

  /// Failures raised while producing platform entropy.
  public enum RappPlatformPrimitiveError: Error, Sendable {
    case entropyUnavailable
    case invalidByteCount
  }
#endif
