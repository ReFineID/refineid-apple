// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import Foundation

  /// Completes a scheme-less authority address by asking the service.
  ///
  /// A holder pasting `tsa.example.com` should not have to know which
  /// scheme the service speaks. Both are tried - https first, and
  /// preferred when it answers at all - and the address is completed
  /// only with a scheme the service actually answered on, never with
  /// a guess.
  internal enum AuthoritySchemeResolver {
    /// How long one probe waits before the scheme is called silent.
    private static let probeTimeout: TimeInterval = 5

    /// Whether the address names a service this app could reach.
    ///
    /// Both schemes are accepted: timestamping is specified over
    /// plain HTTP and several qualified authorities publish exactly
    /// that, so insisting on one scheme would refuse real services.
    internal static func isUsable(_ address: String) -> Bool {
      guard
        let url = URL(string: address),
        let scheme = url.scheme?.lowercased()
      else {
        return false
      }
      return (scheme == "http" || scheme == "https") && url.host != nil
    }

    /// The address completed with the scheme that answered, https
    /// preferred; nil when the entry already names a scheme or
    /// neither answered.
    internal static func complete(_ address: String) async -> String? {
      guard !address.isEmpty, !address.contains("://") else { return nil }
      for scheme in ["https", "http"] {
        let candidate = "\(scheme)://\(address)"
        guard let url = URL(string: candidate), url.host != nil else {
          continue
        }
        if await answers(url) {
          return candidate
        }
      }
      return nil
    }

    /// Whether anything speaks HTTP at this URL.
    ///
    /// Any response counts, an error status included: a time-stamp
    /// service answers POST requests, so what it says to a probing
    /// GET means nothing - that it said anything means everything.
    private static func answers(_ url: URL) async -> Bool {
      var request = URLRequest(url: url)
      request.timeoutInterval = Self.probeTimeout
      let configuration = SigningNetwork.validatedSessionConfiguration(
        validating: true
      )
      configuration.timeoutIntervalForResource = Self.probeTimeout
      let session = URLSession(configuration: configuration)
      defer { session.finishTasksAndInvalidate() }
      return (try? await session.data(for: request)) != nil
    }
  }

#endif
