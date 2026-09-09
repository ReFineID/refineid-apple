// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

#if REFINEID_STREAM_TRANSPORT
  import Network
  import RappEngine
#endif

/// The channel a pairing ceremony runs over, whichever transport carries it.
///
/// Pairing and the sessions that follow it have to travel the same way: a
/// pairing made over a transport the peers cannot use again is a pairing
/// they cannot use. This presents one shape so the ceremony does not know
/// which is underneath.
///
/// Over the stream transport the card holder listens and the requester
/// dials, because that is the direction the network allows: measured on
/// the machines this serves, the holder's listener accepts a connection
/// from every peer, while a listener anywhere else refuses the holder.
/// The requester finds the holder in the name service, under a name both
/// derive from the offer one showed and the other scanned.
internal final class PairingRelay: @unchecked Sendable {
  private let onEvent: @Sendable (PersistentRelayEvent) -> Void

  #if REFINEID_STREAM_TRANSPORT
    private let role: PersistentRelayRole
    private var listener: StreamRelayListener?
    private var browser: StreamRelayBrowser?
    private var dialer: StreamRelaySession?
    private var reportedArrival = false
  #else
    private let session: PersistentRelaySession
  #endif

  /// Builds the channel one side of a ceremony speaks over.
  internal init(
    role: PersistentRelayRole,
    displayName: String,
    onEvent: @escaping @Sendable (PersistentRelayEvent) -> Void
  ) {
    self.onEvent = onEvent
    #if REFINEID_STREAM_TRANSPORT
      self.role = role
    #else
      self.session = PersistentRelaySession(
        role: role,
        displayName: displayName,
        onEvent: onEvent
      )
    #endif
  }

  /// Opens the channel toward the peer the ceremony's offer names.
  ///
  /// Over the stream transport the offer's derived name is the meeting
  /// point, so the channel cannot open before the offer exists. The
  /// nearby transport meets by service type alone and ignores the name.
  internal func start(sharingOfferURI uri: String) {
    #if REFINEID_STREAM_TRANSPORT
      let name = StreamRendezvousName.name(sharingOfferURI: uri)
      switch role {
      case .host:
        print("[pairing-relay] host browsing for name: \(name)")
        Darwin.fflush(stdout)
        let found = StreamRelayBrowser(matching: name) { [weak self] endpoint in
          print("[pairing-relay] browser found endpoint: \(endpoint)")
          Darwin.fflush(stdout)
          self?.dial(endpoint)
        }
        browser = found
        found.start()

      case .cardHolder:
        let made = StreamRelayListener { [weak self] event in
          self?.receiveStream(event)
        }
        listener = made
        made.start(displayName: name)
      }
    #else
      session.start()
    #endif
  }

  #if REFINEID_STREAM_TRANSPORT
    /// Dials the stream candidate's endpoints directly.
    internal func start(dialingEndpoints endpoints: [String]) {
      guard dialer == nil else { return }
      print("[pairing-relay] dialing endpoints: \(endpoints)")
      Darwin.fflush(stdout)
      let made = StreamRelaySession(
        endpointLiterals: endpoints,
        preamble: rappStreamPairingPreamble()
      ) { [weak self] event in
        print("[pairing-relay] session event: \(event)")
        Darwin.fflush(stdout)
        self?.receiveStream(event)
      }
      dialer = made
      made.start()
    }
  #endif

  /// Hands one frame to the peer.
  internal func send(_ frame: Data) async throws {
    #if REFINEID_STREAM_TRANSPORT
      if let dialer {
        try await dialer.send(frame)
      } else if let listener {
        try listener.send(frame)
      } else {
        throw PersistentRelayTransportError.disconnected
      }
    #else
      try session.send(frame)
    #endif
  }

  /// Closes the channel.
  internal func cancel() {
    #if REFINEID_STREAM_TRANSPORT
      listener?.cancel()
      browser?.cancel()
      dialer?.cancel()
    #else
      session.cancel()
    #endif
  }

  #if REFINEID_STREAM_TRANSPORT
    /// Dials the holder once its published listener has been found.
    private func dial(_ endpoint: NWEndpoint) {
      guard dialer == nil else { return }
      print("[pairing-relay] dialing: \(endpoint)")
      Darwin.fflush(stdout)
      let made = StreamRelaySession(
        service: endpoint,
        preamble: rappStreamPairingPreamble()
      ) { [weak self] event in
        print("[pairing-relay] session event: \(event)")
        Darwin.fflush(stdout)
        self?.receiveStream(event)
      }
      dialer = made
      made.start()
    }

    /// Reports a stream event the way the ceremony above names it.
    ///
    /// The dialer's preamble is the arrival itself and carries no message,
    /// so it becomes the connection event rather than a frame. Arrival is
    /// reported once, whichever of the transport's signals lands first.
    private func receiveStream(_ event: StreamRelayEvent) {
      print("[pairing-relay] receiveStream: \(event)")
      Darwin.fflush(stdout)
      if case .frame(let payload) = event,
        payload == rappStreamPairingPreamble() || payload == StreamRelayPreamble.hello
      {
        reportArrival()
        return
      }
      if case .connected = event {
        reportArrival()
        return
      }
      print("[pairing-relay] onEvent(\(PersistentRelayEvent(event)))")
      Darwin.fflush(stdout)
      onEvent(PersistentRelayEvent(event))
    }

    private func reportArrival() {
      guard !reportedArrival else { return }
      reportedArrival = true
      onEvent(.connected)
    }
  #endif
}
