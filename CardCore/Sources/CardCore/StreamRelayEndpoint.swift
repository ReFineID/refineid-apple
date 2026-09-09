// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// One `host:port` listener address; an IPv6 host uses bracket form.
public struct StreamRelayEndpoint: Sendable, Equatable {
  /// Host literal without brackets.
  public let host: String
  /// Nonzero TCP port.
  public let port: UInt16

  /// Parses one listener address literal, or nil when it is not a
  /// nonempty host with a nonzero 16-bit port.
  public init?(literal: String) {
    guard let separator = literal.lastIndex(of: ":") else { return nil }
    var hostPart = String(literal[literal.startIndex..<separator])
    let portPart = literal[literal.index(after: separator)...]
    if hostPart.hasPrefix("["), hostPart.hasSuffix("]") {
      hostPart = String(hostPart.dropFirst().dropLast())
    } else if hostPart.contains(":") {
      return nil
    }
    guard !hostPart.isEmpty,
      let parsedPort = UInt16(portPart), parsedPort != 0
    else { return nil }
    self.host = hostPart
    self.port = parsedPort
  }
}
