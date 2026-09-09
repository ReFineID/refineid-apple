// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD && REFINEID_STREAM_TRANSPORT
  import CardCore
  import Foundation
  import RappEngine

  /// The stream transport's half of the phone relay.
  ///
  /// The holder is the side whose listener every peer can reach, so it
  /// publishes under the active pairs' derived names and waits; the
  /// requester finds the name and dials with the pair's session preamble.
  @MainActor
  extension PhonePersistentTokenRelay {
    /// Listens under each active pair's derived name and waits for any
    /// paired requester to dial, or dials directly for pairs with explicit endpoints.
    internal func startListening(_ contexts: [PhoneStreamPairContext]) {
      for context in contexts {
        streamContexts[context.serviceName] = context
        if !context.streamEndpoints.isEmpty {
          if streamDialers[context.serviceName] != nil || coordinator != nil {
            continue
          }
          #if DEBUG
            print("[stream-holder] dialing \(context.streamEndpoints) for \(context.serviceName)")
            fflush(stdout)
          #endif
          let dialer = StreamRelaySession(
            endpointLiterals: context.streamEndpoints,
            preamble: context.sessionPreamble
          ) { [weak self] event in
            Task { @MainActor in
              self?.receiveDialerEvent(event, from: context.serviceName)
            }
          }
          streamDialers[context.serviceName] = dialer
          dialer.start()
        } else {
          if streamListeners[context.serviceName] != nil {
            continue
          }
          #if DEBUG
            print("[stream-holder] listening as \(context.serviceName)")
            fflush(stdout)
          #endif
          let listener = StreamRelayListener { [weak self] event in
            Task { @MainActor in
              self?.receiveStream(event, from: context.serviceName)
            }
          }
          streamListeners[context.serviceName] = listener
          listener.start(displayName: context.serviceName)
        }
      }
    }

    private func receiveStream(_ event: StreamRelayEvent, from serviceName: String) {
      guard let listener = streamListeners[serviceName],
        let context = streamContexts[serviceName]
      else { return }
      switch event {
      case .connected:
        handleStreamConnected(on: listener, serviceName: serviceName)
      case .frame(let frame):
        handleStreamFrame(frame, from: listener, context: context)
      case .closed:
        handleStreamClosed(from: listener, serviceName: serviceName)
      }
    }

    private func handleStreamConnected(on listener: StreamRelayListener, serviceName: String) {
      if coordinator != nil {
        #if DEBUG
          print(
            "[stream-holder] already connected to a peer, "
              + "disconnecting incoming on \(serviceName)")
          fflush(stdout)
        #endif
        listener.disconnect()
        return
      }
      activeStreamListener = listener
      connectionID = UUID()
      lastPeerContactDate = Date()
      #if DEBUG
        print("[stream-holder] a dialer arrived on \(serviceName)")
        fflush(stdout)
      #endif
    }

    private func handleStreamFrame(
      _ frame: Data,
      from listener: StreamRelayListener,
      context: PhoneStreamPairContext
    ) {
      guard activeStreamListener === listener,
        let currentConnectionID = connectionID
      else { return }
      lastPeerContactDate = Date()
      #if DEBUG
        let expected = context.sessionPreamble.count
        print(
          "[stream-holder] frame \(frame.count) bytes, preamble \(expected), "
            + "match \(frame == context.sessionPreamble), "
            + "session \(coordinator != nil)")
        fflush(stdout)
      #endif
      if let matched = matchedPair(forPreamble: frame) {
        establishStream(connectionID: currentConnectionID, pair: matched, listener: listener)
      } else if let coordinator {
        deliverInOrder { await coordinator.receive(frame) }
      } else if preCoordinatorFrames.count < Self.maximumPreCoordinatorFrames {
        preCoordinatorFrames.append(frame)
      } else {
        listener.disconnect()
      }
    }

    private func handleStreamClosed(from listener: StreamRelayListener, serviceName: String) {
      #if DEBUG
        print("[stream-holder] receiveStream .closed event on \(serviceName)")
        fflush(stdout)
      #endif
      guard activeStreamListener === listener else { return }
      activeStreamListener = nil
      if listener.isListening {
        handleConnectionClosed()
      } else {
        handleTransportClosed(
          redialDelayMilliseconds: Self.streamRedialDelayMilliseconds
        )
      }
    }

    private func matchedPair(forPreamble frame: Data) -> RappPairRecord? {
      guard let activeIDs = try? vault.activePairIDs() else { return nil }
      for pairID in activeIDs {
        guard let pair = try? RappPairRecord.loadFromVault(pairId: pairID, vault: vault) else {
          continue
        }
        if let preamble = try? rappStreamSessionPreamble(
          rendezvousToken: pair.metadata().rendezvousToken
        ), frame == preamble {
          return pair
        }
      }
      return nil
    }

    private func establishStream(
      connectionID: UUID,
      pair: RappPairRecord,
      listener: StreamRelayListener
    ) {
      guard self.connectionID == connectionID, coordinator == nil else { return }

      let transport = RappClosureFrameTransport(
        sender: { [weak listener] frame in
          guard let listener else {
            throw StreamRelayTransportError.notConnected
          }
          try listener.send(frame)
        },
        closer: { [weak listener] in listener?.disconnect() }
      )
      establishCoordinator(
        connectionID: connectionID,
        pair: pair,
        transport: transport
      ) { [weak listener] in
        listener?.disconnect()
      }
    }

    private func receiveDialerEvent(_ event: StreamRelayEvent, from serviceName: String) {
      guard let dialer = streamDialers[serviceName],
        let context = streamContexts[serviceName]
      else { return }
      switch event {
      case .connected:
        handleDialerConnected(on: dialer, context: context)
      case .frame(let frame):
        handleDialerFrame(frame, from: dialer)
      case .closed:
        handleDialerClosed(from: dialer, serviceName: serviceName)
      }
    }

    private func handleDialerConnected(
      on dialer: StreamRelaySession,
      context: PhoneStreamPairContext
    ) {
      if coordinator != nil {
        #if DEBUG
          print(
            "[stream-holder] already connected to a peer, "
              + "cancelling dialer on \(context.serviceName)")
          fflush(stdout)
        #endif
        dialer.cancel()
        streamDialers.removeValue(forKey: context.serviceName)
        return
      }
      activeStreamDialer = dialer
      let currentConnectionID = UUID()
      connectionID = currentConnectionID
      lastPeerContactDate = Date()
      #if DEBUG
        print("[stream-holder] dialer connected on \(context.serviceName)")
        fflush(stdout)
      #endif
      let transport = RappClosureFrameTransport(
        sender: { [weak dialer] frame in
          guard let dialer else {
            throw StreamRelayTransportError.notConnected
          }
          try await dialer.send(frame)
        },
        closer: { [weak dialer] in dialer?.cancel() }
      )
      establishCoordinator(
        connectionID: currentConnectionID,
        pair: context.pairRecord,
        transport: transport
      ) { [weak dialer] in
        dialer?.cancel()
      }
    }

    private func handleDialerFrame(
      _ frame: Data,
      from dialer: StreamRelaySession
    ) {
      guard activeStreamDialer === dialer,
        connectionID != nil
      else { return }
      lastPeerContactDate = Date()
      #if DEBUG
        print(
          "[stream-holder] dialer received frame \(frame.count) bytes, "
            + "session \(coordinator != nil)")
        fflush(stdout)
      #endif
      if let coordinator {
        deliverInOrder { await coordinator.receive(frame) }
      } else if preCoordinatorFrames.count < Self.maximumPreCoordinatorFrames {
        preCoordinatorFrames.append(frame)
      } else {
        dialer.cancel()
      }
    }

    private func handleDialerClosed(from dialer: StreamRelaySession, serviceName: String) {
      #if DEBUG
        print("[stream-holder] dialer .closed event on \(serviceName)")
        fflush(stdout)
      #endif
      if activeStreamDialer === dialer {
        activeStreamDialer = nil
      }
      streamDialers.removeValue(forKey: serviceName)
      handleTransportClosed(
        redialDelayMilliseconds: Self.streamRedialDelayMilliseconds
      )
    }
  }
#endif
