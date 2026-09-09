// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG

  import CardCore
  import Foundation

  /// Answers whether this device can be dialled at all.
  ///
  /// The requester's half of the relay is a listener, and a listener that
  /// reports itself ready while its port refuses connections is
  /// indistinguishable, from the other device, from a peer that is not
  /// there. This opens one, dials it from this same device, and says what
  /// happened -- so a refusal on the network can be told apart from a
  /// listener that never really opened.
  ///
  /// DEBUG only.
  internal enum DebugListenProbe {
    // MARK: Static Properties

    private static let bindAttempts = 50
    private static let bindPauseMilliseconds = 100
    private static let bindPause = Duration.milliseconds(bindPauseMilliseconds)
    private static let dialAttempts = 50
    private static let dialPauseMilliseconds = 200
    private static let dialPause = Duration.milliseconds(dialPauseMilliseconds)
    private static let greeting = Data("listen-probe".utf8)

    // MARK: Static Functions

    /// Opens a listener, dials it, and reports what each side saw.
    internal static func run() async -> DebugModeReport {
      let arrivals = DebugProbeTrail()
      let listener = StreamRelayListener { event in
        Task { await arrivals.record(String(describing: event)) }
      }
      listener.start(displayName: "RefineID listen probe")
      defer { listener.cancel() }

      var bound: UInt16?
      for _ in 0..<bindAttempts where bound == nil {
        if let port = listener.port, port != 0 {
          bound = port
        } else {
          try? await Task.sleep(for: bindPause)
        }
      }
      guard let port = bound else {
        return DebugModeReport(
          lines: ["listen-probe: never bound a port", "listen-probe: " + listener.state],
          succeeded: false)
      }

      var lines = ["listen-probe: bound port " + String(port)]
      lines.append("listen-probe: endpoints " + endpointSummary(port: port))

      let dialer = StreamRelaySession(
        endpointLiterals: ["127.0.0.1:" + String(port)],
        preamble: greeting
      ) { event in
        Task { await arrivals.record("dialer " + String(describing: event)) }
      }
      dialer.start()
      defer { dialer.cancel() }

      for _ in 0..<dialAttempts {
        if await arrivals.contains("frame") { break }
        try? await Task.sleep(for: dialPause)
      }

      let seen = await arrivals.summary
      lines.append("listen-probe: listener " + listener.state)
      lines.append("listen-probe: saw " + seen)
      return DebugModeReport(lines: lines, succeeded: await arrivals.contains("frame"))
    }

    /// The addresses this device would advertise for `port`.
    private static func endpointSummary(port: UInt16) -> String {
      let endpoints = StreamRelayLocalEndpoints.endpoints(port: port)
      return endpoints.isEmpty ? "none" : endpoints.joined(separator: " ")
    }
  }

#endif
