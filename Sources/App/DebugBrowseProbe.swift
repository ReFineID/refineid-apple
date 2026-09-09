// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import CardCore
  import Foundation
  import Network

  /// Answers whether this device receives service announcements at all.
  ///
  /// Every discovery path here rides the multicast name service, and a
  /// network that filters it produces exactly one symptom: a browser that
  /// starts cleanly and never reports a peer that is plainly announcing.
  /// This browses for a named type and reports what arrived, so a silent
  /// network can be told apart from a silent peer.
  ///
  /// DEBUG only.
  internal enum DebugBrowseProbe {
    // MARK: Static Properties

    private static let attempts = 40
    private static let pauseMilliseconds = 200
    private static let pause = Duration.milliseconds(pauseMilliseconds)

    // MARK: Static Functions

    /// Browses for `type` and reports every result that appears.
    internal static func run(type: String) async -> DebugModeReport {
      let seen = DebugProbeTrail()
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: parameters)
      browser.browseResultsChangedHandler = { results, _ in
        for result in results {
          guard case .service(let name, let foundType, _, _) = result.endpoint else { continue }
          Task { await seen.record(name + " " + foundType) }
        }
      }
      browser.stateUpdateHandler = { state in
        Task { await seen.record("browser " + String(describing: state)) }
      }
      browser.start(queue: DispatchQueue(label: "fi.refineid.browse-probe"))
      defer { browser.cancel() }

      for _ in 0..<attempts {
        if await seen.contains(type) { break }
        try? await Task.sleep(for: pause)
      }
      let summary = await seen.summary
      return DebugModeReport(
        lines: ["browse-probe: " + type + " saw: " + summary],
        succeeded: await seen.contains(type))
    }
  }

#endif
