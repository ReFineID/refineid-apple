// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One completely received SCS request: the parsed head and its
/// body, ready to dispatch.
public struct ScsHttpExchange: Equatable, Sendable {
  /// The parsed request head.
  public let request: ScsHttpRequest

  /// The request body, exactly `Content-Length` bytes.
  public let body: Data

  /// Builds an exchange for tests and local callers.
  public init(request: ScsHttpRequest, body: Data) {
    self.request = request
    self.body = body
  }
}
