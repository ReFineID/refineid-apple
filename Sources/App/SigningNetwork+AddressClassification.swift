// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Darwin
import Foundation

extension SigningNetwork {
  /// An IPv4 or IPv6 address returned by the system resolver.
  internal enum NumericAddress: Equatable {
    case ipv4(Data)
    case ipv6(Data)
  }

  /// Bytes in an IPv4 address.
  internal static let ipv4ByteCount = 4

  /// The first octet of the IPv4 benchmark range.
  private static let ipv4BenchmarkFirstOctet: UInt8 = 198

  /// The first second octet assigned to IPv4 benchmarking.
  private static let ipv4BenchmarkFirstSecondOctet: UInt8 = 18

  /// The second second octet assigned to IPv4 benchmarking.
  private static let ipv4BenchmarkSecondSecondOctet: UInt8 = 19

  /// The IPv4 documentation address's first octet.
  private static let ipv4DocumentationFirstOctet: UInt8 = 203

  /// The IPv4 documentation address's second octet.
  private static let ipv4DocumentationSecondOctet: UInt8 = 0

  /// The IPv4 documentation address's third octet.
  private static let ipv4DocumentationThirdOctet: UInt8 = 113

  /// The IPv4 documentation range reserved for TEST-NET-2's second octet.
  private static let ipv4DocumentationTwoSecondOctet: UInt8 = 51

  /// The IPv4 documentation range reserved for TEST-NET-2's third octet.
  private static let ipv4DocumentationTwoThirdOctet: UInt8 = 100

  /// The first octet of the IPv4 link-local range.
  private static let ipv4LinkLocalFirstOctet: UInt8 = 169

  /// The second octet of the IPv4 link-local range.
  private static let ipv4LinkLocalSecondOctet: UInt8 = 254

  /// The first octet of IPv4 loopback addresses.
  private static let ipv4LoopbackFirstOctet: UInt8 = 127

  /// The first octet of IPv4 multicast and reserved ranges.
  private static let ipv4MulticastFirstOctet: UInt8 = 224

  /// The first octet of the private IPv4 10/8 range.
  private static let ipv4PrivateTenFirstOctet: UInt8 = 10

  /// The first octet of the private IPv4 172.16/12 range.
  private static let ipv4Private172FirstOctet: UInt8 = 172

  /// The second-octet range of the private IPv4 172.16/12 range.
  private static let ipv4Private172SecondOctets: ClosedRange<UInt8> = 16...31

  /// The first octet of the private IPv4 192.168/16 range.
  private static let ipv4Private192FirstOctet: UInt8 = 192

  /// The second octet of the private IPv4 192.168/16 range.
  private static let ipv4Private192SecondOctet: UInt8 = 168

  /// The first octet of the IPv4 shared address space.
  private static let ipv4SharedFirstOctet: UInt8 = 100

  /// The second-octet range of the IPv4 shared address space.
  private static let ipv4SharedSecondOctets: ClosedRange<UInt8> = 64...127

  /// The first octet of the IPv4 special-purpose 192.0.0/24 range.
  private static let ipv4SpecialPurposeFirstOctet: UInt8 = 192

  /// The second octet of the IPv4 special-purpose 192.0.0/24 range.
  private static let ipv4SpecialPurposeSecondOctet: UInt8 = 0

  /// The first octet of IPv4's unspecified range.
  private static let ipv4UnspecifiedFirstOctet: UInt8 = 0

  /// The largest DNS answer set accepted for one certificate endpoint.
  ///
  /// A larger answer is refused rather than leaving part of it unchecked.
  private static let maximumResolvedAddresses = 8

  /// Returns one vetted public DNS answer, refusing mixed or oversized sets.
  ///
  /// The caller uses this exact numeric answer rather than resolving again.
  internal static func publicResolvedAddress(for host: String) -> NumericAddress? {
    let addresses = Self.resolvedAddresses(for: host)
    guard !addresses.isEmpty, addresses.allSatisfy(Self.isPublic) else {
      return nil
    }
    return addresses.first
  }

  /// Parses a standard numeric literal without performing DNS.
  internal static func numericAddress(_ host: String) -> NumericAddress? {
    var ipv4 = in_addr()
    if host.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
      return .ipv4(Self.data(of: ipv4))
    }
    var ipv6 = in6_addr()
    if host.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 {
      return .ipv6(Self.data(of: ipv6))
    }
    return nil
  }

  /// Resolves a hostname once so every possible destination can be checked
  /// before URLSession is allowed to contact it.
  private static func resolvedAddresses(for host: String) -> [NumericAddress] {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    // One entry per address, not one per socket type. Without this
    // getaddrinfo answers each address once per stream, datagram and
    // raw type, so a CDN-hosted CA - three addresses,
    // nine entries - was refused for a cap it never reached.
    hints.ai_socktype = SOCK_STREAM
    var result: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(host, nil, &hints, &result) == 0, let result else {
      return []
    }
    defer { freeaddrinfo(result) }
    var addresses: [NumericAddress] = []
    var node: UnsafeMutablePointer<addrinfo>? = result
    while let info = node {
      guard let socketAddress = info.pointee.ai_addr else {
        node = info.pointee.ai_next
        continue
      }
      switch info.pointee.ai_family {
      case AF_INET:
        let address = socketAddress.withMemoryRebound(
          to: sockaddr_in.self, capacity: 1
        ) { $0.pointee.sin_addr }
        addresses.append(.ipv4(Self.data(of: address)))

      case AF_INET6:
        let address = socketAddress.withMemoryRebound(
          to: sockaddr_in6.self, capacity: 1
        ) { $0.pointee.sin6_addr }
        addresses.append(.ipv6(Self.data(of: address)))

      default:
        break
      }
      node = info.pointee.ai_next
    }
    // The cap counts distinct addresses, which is what the check
    // downstream actually walks; a name resolving to the same
    // address twice has not widened anything.
    var distinct: [NumericAddress] = []
    for address in addresses where !distinct.contains(address) {
      distinct.append(address)
      if distinct.count > Self.maximumResolvedAddresses {
        return []
      }
    }
    return distinct
  }

  /// The in-memory network-order bytes of one socket address member.
  private static func data<Value>(of value: Value) -> Data {
    var copy = value
    return withUnsafeBytes(of: &copy) { Data($0) }
  }

  /// Whether a numeric address is globally routable enough for a
  /// certificate-published endpoint.
  internal static func isPublic(_ address: NumericAddress) -> Bool {
    switch address {
    case .ipv4(let bytes):
      Self.isPublicIpv4(bytes)

    case .ipv6(let bytes):
      Self.isPublicIpv6(bytes)
    }
  }

  /// Rejects IPv4 loopback, private, link-local, multicast, and special
  /// purpose ranges that cannot be safe certificate retrieval targets.
  internal static func isPublicIpv4(_ bytes: Data) -> Bool {
    guard
      bytes.count == Self.ipv4ByteCount,
      let first = bytes.first,
      let second = bytes.dropFirst().first,
      let third = bytes.dropFirst().dropFirst().first
    else { return false }
    return !Self.isPrivateOrSpecialIpv4(
      first: first,
      second: second
    )
      && !Self.isDocumentationIpv4(
        first: first,
        second: second,
        third: third
      )
  }

  /// Whether the first octets identify a private or special IPv4 range.
  private static func isPrivateOrSpecialIpv4(
    first: UInt8,
    second: UInt8
  ) -> Bool {
    if first == Self.ipv4UnspecifiedFirstOctet || first == Self.ipv4PrivateTenFirstOctet
      || first == Self.ipv4LoopbackFirstOctet || first >= Self.ipv4MulticastFirstOctet
    {
      return true
    }
    if first == Self.ipv4SharedFirstOctet,
      Self.ipv4SharedSecondOctets.contains(second)
    {
      return true
    }
    if first == Self.ipv4LinkLocalFirstOctet,
      second == Self.ipv4LinkLocalSecondOctet
    {
      return true
    }
    if first == Self.ipv4Private172FirstOctet,
      Self.ipv4Private172SecondOctets.contains(second)
    {
      return true
    }
    if first == Self.ipv4Private192FirstOctet,
      second == Self.ipv4Private192SecondOctet
    {
      return true
    }
    if first == Self.ipv4SpecialPurposeFirstOctet,
      second == Self.ipv4SpecialPurposeSecondOctet
    {
      return true
    }
    if first == Self.ipv4BenchmarkFirstOctet,
      second == Self.ipv4BenchmarkFirstSecondOctet
    {
      return true
    }
    if first == Self.ipv4BenchmarkFirstOctet,
      second == Self.ipv4BenchmarkSecondSecondOctet
    {
      return true
    }
    return false
  }

  /// Whether the first octets identify one of the IPv4 documentation nets.
  private static func isDocumentationIpv4(
    first: UInt8,
    second: UInt8,
    third: UInt8
  ) -> Bool {
    if first == Self.ipv4BenchmarkFirstOctet,
      second == Self.ipv4DocumentationTwoSecondOctet,
      third == Self.ipv4DocumentationTwoThirdOctet
    {
      return true
    }
    if first == Self.ipv4DocumentationFirstOctet,
      second == Self.ipv4DocumentationSecondOctet,
      third == Self.ipv4DocumentationThirdOctet
    {
      return true
    }
    return false
  }
}
