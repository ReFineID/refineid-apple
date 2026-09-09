// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(Network)
  import Network

  /// Watches whether one named stream-transport service is on the network.
  ///
  /// A one-shot browser reports the first find and stops caring. A requester
  /// that has already published a borrowed identity has to know when that
  /// service leaves, so the identity can leave with it.
  public final class StreamRelayPresence: @unchecked Sendable {
    /// The primary Bonjour service name this watcher browses for.
    public var name: String { matchingNames.first ?? "" }
    /// The set of Bonjour service names this watcher browses for.
    public let matchingNames: Set<String>
    private let onChange: @Sendable (Bool, String?) -> Void
    private let queue = DispatchQueue(label: "fi.refineid.stream-presence")
    private var browser: NWBrowser?
    private var isPresent = false
    private var currentMatchedName: String?
    private var hasDelivered = false

    /// Reports presence of any service published under `names`.
    @preconcurrency
    public init(
      matching names: Set<String>,
      onChange: @escaping @Sendable (Bool, String?) -> Void
    ) {
      self.matchingNames = names
      self.onChange = onChange
    }

    /// Reports presence of the service published under `name`.
    @preconcurrency
    public convenience init(
      matching name: String,
      onChange: @escaping @Sendable (Bool) -> Void
    ) {
      self.init(matching: [name]) { present, _ in
        onChange(present)
      }
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
        self?.apply(results)
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

    private func apply(_ results: Set<NWBrowser.Result>) {
      guard !matchingNames.isEmpty else {
        if isPresent {
          isPresent = false
          currentMatchedName = nil
          onChange(false, nil)
        }
        return
      }
      var matchedName: String?
      for result in results {
        guard case .service(let serviceName, _, _, _) = result.endpoint else {
          continue
        }
        if matchingNames.contains(serviceName) {
          matchedName = serviceName
          break
        }
      }
      let found = matchedName != nil
      if !hasDelivered {
        hasDelivered = true
        isPresent = found
        currentMatchedName = matchedName
        if found {
          onChange(true, matchedName)
        }
        return
      }
      guard found != isPresent || matchedName != currentMatchedName else { return }
      isPresent = found
      currentMatchedName = matchedName
      onChange(found, matchedName)
    }
  }
#endif
