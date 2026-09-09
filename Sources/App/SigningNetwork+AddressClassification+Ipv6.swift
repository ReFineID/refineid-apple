// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension SigningNetwork {
  /// Bytes in an IPv6 address.
  private static let ipv6ByteCount = 16

  /// Zero bytes before the IPv4-compatible suffix in an IPv6 address.
  private static let ipv6CompatiblePrefixLength = 12

  /// The first octet of the IPv6 documentation prefix.
  private static let ipv6DocumentationFirstOctet: UInt8 = 32

  /// The second octet of the IPv6 documentation prefix.
  private static let ipv6DocumentationSecondOctet: UInt8 = 1

  /// The third octet of the IPv6 documentation prefix.
  private static let ipv6DocumentationThirdOctet: UInt8 = 13

  /// The fourth octet of the IPv6 documentation prefix.
  private static let ipv6DocumentationFourthOctet: UInt8 = 184

  /// The first octet of IPv6 link-local addresses.
  private static let ipv6LinkLocalFirstOctet: UInt8 = 254

  /// The second-octet range of IPv6 link-local addresses.
  private static let ipv6LinkLocalSecondOctets: ClosedRange<UInt8> = 128...191

  /// The first octet of the deprecated IPv6 site-local range.
  private static let ipv6SiteLocalFirstOctet: UInt8 = 254

  /// The second-octet range of the deprecated IPv6 site-local range.
  private static let ipv6SiteLocalSecondOctets: ClosedRange<UInt8> = 192...255

  /// Zero bytes before the IPv4-mapped suffix in an IPv6 address.
  private static let ipv6MappedPrefixLength = 10

  /// The value of one all-bits-set octet.
  private static let allBitsSetOctet: UInt8 = 255

  /// The two marker octets in an IPv4-mapped IPv6 address.
  private static let ipv6MappedMarker = Data([
    Self.allBitsSetOctet,
    Self.allBitsSetOctet,
  ])

  /// The first octet of IPv6 multicast addresses.
  private static let ipv6MulticastFirstOctet = Self.allBitsSetOctet

  /// The first octet of the IPv6 6to4 prefix.
  private static let ipv6SixToFourFirstOctet: UInt8 = 32

  /// The second octet of the IPv6 6to4 prefix.
  private static let ipv6SixToFourSecondOctet: UInt8 = 2

  /// The IPv6 6to4 prefix.
  private static let ipv6SixToFourPrefix = Data([
    Self.ipv6SixToFourFirstOctet,
    Self.ipv6SixToFourSecondOctet,
  ])

  /// The second octet of the NAT64 prefixes.
  private static let ipv6Nat64SecondOctet: UInt8 = 100

  /// The fourth octet of the NAT64 prefixes.
  private static let ipv6Nat64FourthOctet: UInt8 = 155

  /// The well-known NAT64 prefix, whose final 32 bits are an IPv4 address.
  private static let ipv6WellKnownNat64Prefix = Data([
    0, Self.ipv6Nat64SecondOctet, Self.allBitsSetOctet,
    Self.ipv6Nat64FourthOctet, 0, 0, 0, 0, 0, 0, 0, 0,
  ])

  /// The local-use NAT64 prefix, which must never be reached as public.
  private static let ipv6LocalUseNat64Prefix = Data([
    0, Self.ipv6Nat64SecondOctet, Self.allBitsSetOctet,
    Self.ipv6Nat64FourthOctet, 0, 1,
  ])

  /// The first-octet range of IPv6 unique-local addresses.
  private static let ipv6UniqueLocalFirstOctets: ClosedRange<UInt8> = 252...253

  /// The value of one zero octet.
  private static let zeroOctet: UInt8 = 0

  /// The value of one octet used by the IPv6 loopback address.
  private static let oneOctet: UInt8 = 1

  /// Rejects IPv6 loopback, local, multicast, documentation, and IPv4
  /// mapped forms whose embedded address is not public.
  internal static func isPublicIpv6(_ bytes: Data) -> Bool {
    guard bytes.count == Self.ipv6ByteCount else { return false }
    if bytes.allSatisfy({ $0 == Self.zeroOctet }) { return false }
    if bytes.dropLast().allSatisfy({ $0 == Self.zeroOctet }),
      bytes.last == Self.oneOctet
    {
      return false
    }
    if let embeddedIpv4 = Self.embeddedIpv4(in: bytes) {
      return Self.isPublicIpv4(embeddedIpv4)
    }
    guard let first = bytes.first, let second = bytes.dropFirst().first else {
      return false
    }
    return !Self.isPrivateOrSpecialIpv6(
      bytes,
      first: first,
      second: second
    )
  }

  /// Returns an IPv4 address embedded by a recognized IPv6 transition
  /// prefix, or nil if no such prefix applies.
  private static func embeddedIpv4(in bytes: Data) -> Data? {
    if bytes.prefix(Self.ipv6CompatiblePrefixLength)
      .allSatisfy({ $0 == Self.zeroOctet })
    {
      return Data(bytes.suffix(Self.ipv4ByteCount))
    }
    if bytes.prefix(Self.ipv6MappedPrefixLength)
      .allSatisfy({ $0 == Self.zeroOctet }),
      bytes.dropFirst(Self.ipv6MappedPrefixLength)
        .starts(with: Self.ipv6MappedMarker)
    {
      return Data(bytes.suffix(Self.ipv4ByteCount))
    }
    if bytes.starts(with: Self.ipv6WellKnownNat64Prefix) {
      return Data(bytes.suffix(Self.ipv4ByteCount))
    }
    if bytes.starts(with: Self.ipv6SixToFourPrefix) {
      let embeddedStart = Self.ipv6SixToFourPrefix.count
      let embeddedEnd = embeddedStart + Self.ipv4ByteCount
      return Data(bytes[embeddedStart..<embeddedEnd])
    }
    return nil
  }

  /// Whether an IPv6 address is local, reserved, or documentation-only.
  private static func isPrivateOrSpecialIpv6(
    _ bytes: Data,
    first: UInt8,
    second: UInt8
  ) -> Bool {
    if Self.ipv6UniqueLocalFirstOctets.contains(first) || first == Self.ipv6MulticastFirstOctet {
      return true
    }
    if first == Self.ipv6LinkLocalFirstOctet,
      Self.ipv6LinkLocalSecondOctets.contains(second)
    {
      return true
    }
    if first == Self.ipv6SiteLocalFirstOctet,
      Self.ipv6SiteLocalSecondOctets.contains(second)
    {
      return true
    }
    return Self.isDocumentationIpv6(bytes) || bytes.starts(with: Self.ipv6LocalUseNat64Prefix)
  }

  /// Whether an IPv6 address uses the documentation-only 2001:db8::/32.
  private static func isDocumentationIpv6(_ bytes: Data) -> Bool {
    let prefix = bytes.prefix(Self.ipv4ByteCount)
    return prefix.starts(with: [
      Self.ipv6DocumentationFirstOctet,
      Self.ipv6DocumentationSecondOctet,
      Self.ipv6DocumentationThirdOctet,
      Self.ipv6DocumentationFourthOctet,
    ])
  }
}
