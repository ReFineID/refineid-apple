// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Darwin
import Foundation

extension SigningNetwork {
  /// Bytes in an IPv4 socket address.
  private static let ipv4AddressByteCount = 4

  /// Bytes in an IPv6 socket address.
  private static let ipv6AddressByteCount = 16

  /// The largest ASCII byte permitted in an address literal.
  private static let lastAsciiByte: UInt8 = 127

  /// The default HTTP port used when writing a Host header.
  private static let defaultHttpPort = 80

  /// The default HTTPS port used when writing a Host header.
  private static let defaultHttpsPort = 443

  /// An exact HTTP or HTTPS URL, never a lookalike scheme.
  internal static func httpUrl(
    _ address: String,
    for endpoint: Endpoint
  ) throws -> URL {
    guard let url = URL(string: address), Self.isHttpUrl(url) else {
      throw Failure.badAddress
    }
    if endpoint == .certificateMaterial,
      !Self.certificateMaterialUrlIsAllowed(url)
    {
      throw Failure.unsafeAddress
    }
    return url
  }

  /// Prepares a request that originates in certificate material.
  ///
  /// HTTP hostnames are resolved once and rewritten to the vetted numeric
  /// address before URLSession sees them, preventing a second DNS lookup
  /// from changing a public answer into a private one. HTTPS hostnames keep
  /// their name for SNI and certificate validation, after every preflight
  /// answer has been checked public.
  internal static func protectedRequest(
    of request: URLRequest,
    for endpoint: Endpoint
  ) throws -> URLRequest {
    guard endpoint == .certificateMaterial else { return request }
    guard let url = request.url, let host = url.host else {
      throw Failure.unsafeAddress
    }
    guard Self.certificateMaterialUrlIsAllowed(url) else {
      throw Failure.unsafeAddress
    }
    if Self.numericAddress(host) != nil { return request }
    guard let address = Self.publicResolvedAddress(for: host) else {
      throw Failure.unsafeAddress
    }
    return try Self.protectedCertificateMaterialRequest(
      request,
      resolvingTo: [address]
    )
  }

  /// Checks the non-DNS part of an HTTP endpoint.
  internal static func isHttpUrl(_ url: URL) -> Bool {
    guard
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme),
      let host = url.host,
      !host.isEmpty,
      url.user == nil,
      url.password == nil
    else { return false }
    return true
  }

  /// Whether a certificate-published host is not obviously local before
  /// a DNS lookup is attempted.
  internal static func certificateHostCouldBePublic(_ host: String) -> Bool {
    let normalized = Self.normalizedHost(host)
    guard
      !normalized.isEmpty,
      !normalized.contains("%"),
      normalized != "localhost",
      !normalized.hasSuffix(".localhost"),
      normalized != "local",
      !normalized.hasSuffix(".local")
    else { return false }
    if let numeric = Self.numericAddress(host) {
      return Self.isPublic(numeric)
    }
    return !Self.looksLikeNumericAddress(normalized)
  }

  /// Whether a certificate-material URL passes its static target policy.
  ///
  /// DNS names undergo an all-public preflight before they are sent.
  internal static func certificateMaterialUrlIsAllowed(_ url: URL) -> Bool {
    guard
      Self.isHttpUrl(url),
      let host = url.host,
      Self.certificateHostCouldBePublic(host)
    else {
      return false
    }
    if let numeric = Self.numericAddress(host) {
      return Self.isPublic(numeric)
    }
    return true
  }

  /// Applies the testable DNS preflight result to one certificate request.
  ///
  /// HTTPS keeps its original hostname for SNI and certificate validation;
  /// HTTP is pinned to the public answer before dispatch.
  internal static func protectedCertificateMaterialRequest(
    _ request: URLRequest,
    resolvingTo addresses: [NumericAddress]
  ) throws -> URLRequest {
    guard
      let url = request.url,
      Self.certificateMaterialUrlIsAllowed(url),
      let host = url.host
    else {
      throw Failure.unsafeAddress
    }
    if Self.numericAddress(host) != nil { return request }
    guard !addresses.isEmpty, addresses.allSatisfy(Self.isPublic) else {
      throw Failure.unsafeAddress
    }
    if url.scheme?.lowercased() == "https" { return request }
    return try Self.pinnedCertificateMaterialRequest(
      request,
      resolvingTo: addresses
    )
  }

  /// Rewrites one HTTP hostname request to one independently supplied
  /// public DNS answer.
  ///
  /// This is a direct test boundary with no DNS or network activity.
  internal static func pinnedCertificateMaterialRequest(
    _ request: URLRequest,
    resolvingTo addresses: [NumericAddress]
  ) throws -> URLRequest {
    guard
      let url = request.url,
      Self.certificateMaterialUrlIsAllowed(url),
      url.scheme?.lowercased() == "http",
      let host = url.host
    else {
      throw Failure.unsafeAddress
    }
    if Self.numericAddress(host) != nil { return request }
    guard
      let address = addresses.first,
      addresses.allSatisfy(Self.isPublic),
      let replacementHost = Self.urlHost(for: address),
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      throw Failure.unsafeAddress
    }
    components.host = replacementHost
    guard let pinnedUrl = components.url else {
      throw Failure.unsafeAddress
    }
    var pinned = request
    pinned.url = pinnedUrl
    pinned.setValue(Self.hostHeader(for: url), forHTTPHeaderField: "Host")
    return pinned
  }

  /// A lowercased DNS name without its optional absolute-name dot.
  internal static func normalizedHost(_ host: String) -> String {
    let lowercased = host.lowercased()
    guard lowercased.hasSuffix(".") else { return lowercased }
    return String(lowercased.dropLast())
  }

  /// Rejects alternate numeric spellings that system resolvers can treat as
  /// an IP literal even though `inet_pton` deliberately does not.
  internal static func looksLikeNumericAddress(_ host: String) -> Bool {
    guard !host.isEmpty else { return false }
    return host.allSatisfy { character in
      character.isNumber || character == "."
    } || host.hasPrefix("0x")
  }

  /// Formats a numeric address for the host portion of a URL.
  private static func urlHost(for address: NumericAddress) -> String? {
    switch address {
    case .ipv4(let bytes):
      return Self.textAddress(bytes, family: AF_INET, bufferSize: INET_ADDRSTRLEN)

    case .ipv6(let bytes):
      guard
        let text = Self.textAddress(
          bytes,
          family: AF_INET6,
          bufferSize: INET6_ADDRSTRLEN
        )
      else {
        return nil
      }
      return "[\(text)]"
    }
  }

  /// Converts network-order address bytes to the standard numeric form.
  private static func textAddress(
    _ bytes: Data,
    family: Int32,
    bufferSize: Int32
  ) -> String? {
    let expectedByteCount: Int
    switch family {
    case AF_INET:
      expectedByteCount = Self.ipv4AddressByteCount

    case AF_INET6:
      expectedByteCount = Self.ipv6AddressByteCount

    default:
      return nil
    }
    guard bytes.count == expectedByteCount else { return nil }
    return bytes.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> String? in
      guard let baseAddress = source.baseAddress else { return nil }
      var buffer = [CChar](repeating: 0, count: Int(bufferSize))
      guard
        inet_ntop(
          family,
          baseAddress,
          &buffer,
          socklen_t(buffer.count)
        ) != nil
      else {
        return nil
      }
      guard let terminator = buffer.firstIndex(of: 0) else {
        return nil
      }
      let ascii = buffer[..<terminator].map { UInt8(bitPattern: $0) }
      guard ascii.allSatisfy({ $0 > 0 && $0 <= Self.lastAsciiByte }) else {
        return nil
      }
      return String(bytes: ascii, encoding: .utf8)
    }
  }

  /// The Host header for a request whose connection URL was IP-pinned.
  private static func hostHeader(for url: URL) -> String? {
    guard let host = url.host, let scheme = url.scheme?.lowercased() else {
      return nil
    }
    let name = host.contains(":") ? "[\(host)]" : host
    let defaultPort =
      scheme == "https"
      ? Self.defaultHttpsPort
      : Self.defaultHttpPort
    guard let port = url.port, port != defaultPort else { return name }
    return "\(name):\(port)"
  }
}
