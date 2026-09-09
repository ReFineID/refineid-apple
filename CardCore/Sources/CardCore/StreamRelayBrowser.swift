// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(Network)
  import Network

  /// Finds a card holder publishing the stream transport.
  ///
  /// This browses with the plain name service rather than the nearby
  /// framework. Both are fed by the same records, but only one of them
  /// hands the result to the app on a device whose system generation
  /// differs from its peer's.
  public final class StreamRelayBrowser: @unchecked Sendable {
    private let onFound: @Sendable (NWEndpoint) -> Void
    private let name: String?
    private let queue = DispatchQueue(label: "fi.refineid.stream-browser")
    private var browser: NWBrowser?
    private var reported = false

    /// Reports a published requester to one owner.
    ///
    /// A network carries more than one of these, so a caller that knows
    /// which it wants says so; a caller that does not takes the first.
    @preconcurrency
    public init(
      matching name: String? = nil,
      onFound: @escaping @Sendable (NWEndpoint) -> Void
    ) {
      self.name = name
      self.onFound = onFound
    }

    /// Starts browsing.
    public func start() {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let made = NWBrowser(
        for: .bonjour(type: StreamRelayListener.serviceType, domain: nil),
        using: parameters
      )
      made.browseResultsChangedHandler = { [weak self] results, _ in
        guard let self else { return }
        let eps = results.map { "\($0.endpoint)" }
        print("[browser] \(results.count) results matching:\(String(describing: name)) eps:\(eps)")
        Darwin.fflush(stdout)
        let wanted: NWBrowser.Result?
        if let name {
          wanted = results.first { result in
            guard case .service(let serviceName, _, _, _) = result.endpoint else { return false }
            return serviceName == name
          }
        } else {
          wanted = results.first
        }
        guard let first = wanted else { return }
        queue.async { [weak self] in
          guard let self, !reported else { return }
          reported = true
          onFound(first.endpoint)
        }
      }
      made.stateUpdateHandler = { state in
        print("[browser] state: \(state)")
        Darwin.fflush(stdout)
      }
      browser = made
      made.start(queue: queue)
    }

    /// Stops browsing.
    public func cancel() {
      queue.async {
        self.browser?.cancel()
        self.browser = nil
      }
    }
  }
#endif
