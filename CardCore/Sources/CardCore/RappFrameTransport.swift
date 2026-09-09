// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation
  import RappEngine

  /// The sole byte-transport capability required by RAPP.
  ///
  /// Implementations must preserve frame boundaries and report successful
  /// release by returning from ``send(_:)``. They must not parse, log, retry,
  /// or reinterpret frames.
  public protocol RappFrameTransport: Sendable {
    func send(_ frame: Data) async throws
    func close() async
  }
#endif
