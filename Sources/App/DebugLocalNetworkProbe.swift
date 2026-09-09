// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG && canImport(Network)

  import Foundation
  import Network

  /// Tries one connection to an address on this network and says what
  /// happened.
  ///
  /// Local network access is refused silently: browsing returns no peers,
  /// no error is raised, and nothing is logged. A direct connection is
  /// gated by the same permission but does report a state, so this turns
  /// an absence into something a reader can act on.
  internal enum DebugLocalNetworkProbe {
    /// How long to wait before calling the attempt inconclusive.
    private static let deadlineSeconds = 8
    private static let deadline = DispatchTimeInterval.seconds(deadlineSeconds)

    /// Connects to `host` on `port` and reports the outcome.
    internal static func report(host: String, port: UInt16) -> DebugModeReport {
      guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
        return DebugModeReport(lines: ["not a port: \(port)"], succeeded: false)
      }
      let connection = NWConnection(
        host: NWEndpoint.Host(host),
        port: endpointPort,
        using: .tcp
      )
      let settled = DispatchSemaphore(value: 0)
      let outcome = DebugProbeOutcomeBox()

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          outcome.set("ready: the app may reach this network")
          settled.signal()

        case .waiting(let error):
          outcome.set("waiting: \(String(describing: error))")

        case .failed(let error):
          outcome.set("failed: \(String(describing: error))")
          settled.signal()

        case .cancelled:
          settled.signal()

        case .preparing, .setup:
          break

        @unknown default:
          break
        }
      }
      connection.start(queue: .global(qos: .userInitiated))
      let timedOut = settled.wait(timeout: .now() + Self.deadline) != .success
      connection.cancel()

      let line = outcome.value ?? "no state reported"
      return DebugModeReport(
        lines: [
          "target: \(host):\(port)",
          timedOut ? "outcome: \(line) (deadline passed)" : "outcome: \(line)",
        ],
        succeeded: line.hasPrefix("ready")
      )
    }
  }

#endif
