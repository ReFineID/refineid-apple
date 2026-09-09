// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(Darwin)
  import Darwin

  /// Where a listener on this device can be reached from the same network.
  ///
  /// A requester puts these in its offer, so the peer that scans it dials an
  /// address instead of browsing for a service. Browsing is what stopped
  /// working between two system generations; an address in the offer is
  /// carried by the code itself and needs no discovery at all.
  public enum StreamRelayLocalEndpoints {
    // MARK: Static Properties

    /// The loopback addresses, which no other device can reach.
    private static let loopbackNames: Set<String> = ["lo0"]

    /// Interfaces a peer on the same network is reached over: Wi-Fi, wired,
    /// and the link a device brings up for a nearby peer.
    private static let carriedNames: Set<String> = [
      "en0", "en1", "en2", "en3", "en4",
      "bridge0", "bridge100",
      "awdl0", "llw0",
    ]

    // MARK: Static Functions

    /// The endpoints a peer dials to reach `port` on this device.
    ///
    /// IPv4 first: an address that came from DHCP on the same subnet is the
    /// one most likely to be routable both ways, while a link-local IPv6
    /// address needs its zone and is only usable on the interface it came
    /// from.
    public static func endpoints(port: UInt16) -> [String] {
      guard port != 0 else { return [] }
      var addresses: [String] = []
      var head: UnsafeMutablePointer<ifaddrs>?
      guard getifaddrs(&head) == 0, let first = head else { return [] }
      defer { freeifaddrs(head) }

      for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
        guard let raw = interface.pointee.ifa_addr else { continue }
        let name = String(cString: interface.pointee.ifa_name)
        guard !loopbackNames.contains(name), carriedNames.contains(name) else { continue }
        guard raw.pointee.sa_family == UInt8(AF_INET) else { continue }
        guard let address = presentation(of: raw, length: interface.pointee.ifa_addr.pointee.sa_len)
        else { continue }
        let endpoint = address + ":" + String(port)
        if !addresses.contains(endpoint) { addresses.append(endpoint) }
      }
      return addresses
    }

    /// One address in the form a dialer parses, or nothing.
    private static func presentation(
      of address: UnsafeMutablePointer<sockaddr>,
      length: UInt8
    ) -> String? {
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      let result = getnameinfo(
        address,
        socklen_t(length),
        &host,
        socklen_t(host.count),
        nil,
        0,
        NI_NUMERICHOST
      )
      guard result == 0 else { return nil }
      let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
      guard let text = String(bytes: Data(bytes), encoding: .utf8), !text.isEmpty
      else { return nil }
      return text
    }
  }
#endif
