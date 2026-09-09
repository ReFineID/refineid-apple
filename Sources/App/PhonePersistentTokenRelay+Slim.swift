// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD && REFINEID_SLIM_RELAY
  import CardCore
  import Foundation
  import RappEngine

  /// The slim relay's proxy side, served over the persistent transport.
  extension PhonePersistentTokenRelay {
    /// Serves the slim relay over the selected pairing, replaying any
    /// frames that arrived before the session existed.
    internal func establishSlim(
      pair: RappPairRecord,
      transport: RappClosureFrameTransport
    ) throws {
      let session = try SignRelaySession(role: .proxy, pair: pair, vault: vault)
      slimSession = session
      isActivelyConnected = true
      let journal = (try? vault.selectedPairID()).flatMap { pairID in
        pairID.map { SignRelayVaultJournal(vault: vault, pairID: $0) }
      }
      slimProxy = SignRelayProxy(journal: journal) { request in
        #if REFINEID_LOCAL_CARD
          return await SlimCardWork.perform(request)
        #else
          // A device with no card path can serve nobody else's request.
          return .failure(requestID: request.requestID, reason: .cardUnavailable)
        #endif
      }
      _ = transport
      let earlyFrames = preCoordinatorFrames
      preCoordinatorFrames.removeAll(keepingCapacity: false)
      for frame in earlyFrames {
        deliverInOrder { [weak self] in await self?.receiveSlim(frame) }
      }
    }

    /// Drives one frame through the slim session and answers what it asks.
    internal func receiveSlim(_ frame: Data) async {
      guard let session = slimSession, let proxy = slimProxy else { return }
      let step: SignRelayStep
      do {
        step = try await session.receive(frame)
      } catch {
        relay?.cancel()
        return
      }
      for outgoing in step.send {
        try? relay?.send(outgoing)
      }
      guard let payload = step.payload else { return }
      guard let answer = try? await proxy.answer(to: payload) else { return }
      guard let sealed = try? await session.seal(answer) else { return }
      try? relay?.send(sealed)
    }
  }
#endif
