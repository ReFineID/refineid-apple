// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(RappEngine)
  import Foundation

  /// Adapts an existing platform transport without giving it any RAPP semantic
  /// authority. The closures must preserve frame boundaries and return only after
  /// the frame was released to the underlying transport.
  public actor RappClosureFrameTransport: RappFrameTransport {
    /// Releases one complete frame to the underlying transport.
    public typealias Sender = @Sendable (Data) async throws -> Void
    /// Tears down the underlying transport.
    public typealias Closer = @Sendable () async -> Void

    private let sender: Sender
    private let closer: Closer
    private var isClosed = false

    /// Wraps the two transport closures.
    public init(sender: @escaping Sender, closer: @escaping Closer) {
      self.sender = sender
      self.closer = closer
    }

    /// Forwards one frame, refusing to send after close.
    public func send(_ frame: Data) async throws {
      guard !isClosed else { throw CancellationError() }
      try await sender(frame)
    }

    /// Closes once; later sends are refused and later closes do nothing.
    public func close() async {
      guard !isClosed else { return }
      isClosed = true
      await closer()
    }
  }
#endif
