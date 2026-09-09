// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if canImport(MultipeerConnectivity)
  @preconcurrency import MultipeerConnectivity
  import os

  /// A single encrypted MultipeerConnectivity transport.
  ///
  /// The transport carries opaque RAPP frames and never decodes protocol or
  /// card-operation data. Peer authentication belongs to RAPP rather than
  /// MultipeerConnectivity discovery.
  public final class PersistentRelaySession: NSObject, @unchecked Sendable,
    MCSessionDelegate, MCNearbyServiceAdvertiserDelegate,
    MCNearbyServiceBrowserDelegate
  {
    private static let serviceType = "refineid-rly"

    /// The peer identity each role advertises under, for as long as this
    /// process lives.
    ///
    /// One per launch, and no longer. Kept between launches it went stale
    /// and stopped being found; made afresh for every channel the holder
    /// became a different peer after each exchange, and a browser looking
    /// for the peer it had just been talking to found churn instead.
    private static let peerIdentities = OSAllocatedUnfairLock<[String: MCPeerID]>(
      initialState: [:]
    )
    private static let invitationRetry: TimeInterval = 3
    private static let invitationTimeout: TimeInterval = 10

    private let role: PersistentRelayRole
    private let localPeer: MCPeerID
    private let session: MCSession
    private let onEvent: @Sendable (PersistentRelayEvent) -> Void
    private let closed = OSAllocatedUnfairLock(initialState: false)
    private let everConnected = OSAllocatedUnfairLock(initialState: false)
    private let lastInviteAt = OSAllocatedUnfairLock<Date?>(initialState: nil)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// The most recently discovered peer, written on the browser's queue
    /// and read on the session's.
    private let lastFoundPeer = OSAllocatedUnfairLock<MCPeerID?>(initialState: nil)

    /// The one peer this channel has taken into its session, with when it
    /// was taken; written on the advertiser's queue and read on the
    /// session's.
    ///
    /// A device runs more than one process that speaks this service: the
    /// app and its token extension both advertise and both invite. Taking
    /// the second invitation replaced a live session with one belonging to
    /// another process, and when that process went away it closed the
    /// channel the first was still using. The timestamp bounds the claim:
    /// an accepted peer that never connects would otherwise hold its place
    /// forever and refuse every later inviter.
    private let acceptedPeer = OSAllocatedUnfairLock<(peer: MCPeerID, at: Date)?>(
      initialState: nil)

    /// Builds a channel for one role that reports to one owner.
    @preconcurrency
    public init(
      role: PersistentRelayRole,
      displayName: String,
      onEvent: @escaping @Sendable (PersistentRelayEvent) -> Void
    ) {
      self.role = role
      self.localPeer = Self.persistentPeer(displayName: displayName, role: role)
      self.session = MCSession(
        peer: localPeer,
        securityIdentity: nil,
        encryptionPreference: .required
      )
      self.onEvent = onEvent
      super.init()
      session.delegate = self
    }

    /// A peer identity for this channel, shared by every channel this
    /// process opens in the same role.
    ///
    /// Peers are authenticated by the pairing's own transcript, so what a
    /// channel calls itself during discovery carries no authority.
    private static func persistentPeer(
      displayName: String,
      role: PersistentRelayRole
    ) -> MCPeerID {
      let roleName = role == .cardHolder ? "card" : "host"
      let key = "\(roleName).\(displayName)"
      return peerIdentities.withLock { identities in
        if let peer = identities[key] { return peer }
        let peer = MCPeerID(displayName: displayName)
        identities[key] = peer
        return peer
      }
    }

    /// Advertises or browses, by role.
    public func start() {
      switch role {
      case .cardHolder:
        let advertiser = MCNearbyServiceAdvertiser(
          peer: localPeer,
          discoveryInfo: nil,
          serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

      case .host:
        let browser = MCNearbyServiceBrowser(
          peer: localPeer,
          serviceType: Self.serviceType
        )
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
      }
      trace("started role=\(role)")
    }

    /// Sends one opaque frame to the connected peer, or throws.
    public func send(_ frame: Data) throws {
      guard !session.connectedPeers.isEmpty else {
        throw PersistentRelayTransportError.disconnected
      }
      do {
        try session.send(
          frame,
          toPeers: session.connectedPeers,
          with: .reliable
        )
      } catch let error as PersistentRelayTransportError {
        throw error
      } catch {
        throw PersistentRelayTransportError.send(String(describing: error))
      }
    }

    /// Stops discovery, disconnects, and reports the channel closed.
    public func cancel() {
      advertiser?.stopAdvertisingPeer()
      browser?.stopBrowsingForPeers()
      session.disconnect()
      finish(.cancelled)
    }

    private func finish(_ error: PersistentRelayTransportError) {
      let wasClosed = closed.withLock { value -> Bool in
        if value { return true }
        value = true
        return false
      }
      guard !wasClosed else { return }
      trace("closed \(String(describing: error))")
      acceptedPeer.withLock { $0 = nil }
      advertiser?.stopAdvertisingPeer()
      browser?.stopBrowsingForPeers()
      onEvent(.closed(error))
    }

    private func invite(_ peer: MCPeerID) {
      guard let browser, session.connectedPeers.isEmpty else { return }
      let shouldInvite = lastInviteAt.withLock { last -> Bool in
        let now = Date()
        if let last, now.timeIntervalSince(last) < Self.invitationRetry {
          return false
        }
        last = now
        return true
      }
      guard shouldInvite else { return }
      browser.invitePeer(
        peer,
        to: session,
        withContext: nil,
        timeout: Self.invitationTimeout
      )
      trace("invited \(peer.displayName)")
    }

    /// Tracks the one connection and re-invites a lost first attempt.
    public func session(
      _: MCSession,
      peer peerID: MCPeerID,
      didChange state: MCSessionState
    ) {
      switch state {
      case .connected:
        everConnected.withLock { $0 = true }
        onEvent(.connected)
        trace("connected \(peerID.displayName)")

      case .notConnected:
        trace("not connected \(peerID.displayName)")
        // The peer being served has left, so the next one may be served.
        // A device asks over more than one process -- the app for a
        // pairing, its token extension for a signature -- and holding the
        // departed peer's place refused every later process forever, which
        // is one working exchange and then none.
        acceptedPeer.withLock { accepted in
          if accepted?.peer.displayName == peerID.displayName {
            accepted = nil
          }
        }
        if everConnected.withLock({ $0 }) {
          finish(.disconnected)
        } else if let peer = lastFoundPeer.withLock({ $0 }) {
          invite(peer)
        }

      case .connecting:
        trace("connecting \(peerID.displayName)")

      @unknown default:
        break
      }
    }

    /// Hands one opaque frame to the owner without interpreting it.
    public func session(
      _: MCSession,
      didReceive data: Data,
      fromPeer _: MCPeerID
    ) {
      onEvent(.frame(data))
    }

    /// Streams are not part of the protocol; ignored.
    public func session(
      _: MCSession,
      didReceive _: InputStream,
      withName _: String,
      fromPeer _: MCPeerID
    ) {
      // streams are not part of the protocol
    }

    /// Resources are not part of the protocol; ignored.
    public func session(
      _: MCSession,
      didStartReceivingResourceWithName _: String,
      fromPeer _: MCPeerID,
      with _: Progress
    ) {
      // resources are not part of the protocol
    }

    /// Resources are not part of the protocol; ignored.
    public func session(
      _: MCSession,
      didFinishReceivingResourceWithName _: String,
      fromPeer _: MCPeerID,
      at _: URL?,
      withError _: (any Error)?
    ) {
      // resources are not part of the protocol
    }

    /// Accepts one inviter into the encrypted session, and only that one.
    ///
    /// The first invitation is taken and its peer remembered. A later
    /// invitation is taken only if it is that same peer arriving again,
    /// which is what a dropped connection looks like from here. Anything
    /// else is refused while the accepted peer holds its place - already
    /// connected or still connecting - because a channel serves one peer
    /// at a time, and a second peer taken mid-connect would put two peers
    /// in one session with every frame delivered to both.
    public func advertiser(
      _: MCNearbyServiceAdvertiser,
      didReceiveInvitationFromPeer peerID: MCPeerID,
      withContext _: Data?,
      invitationHandler: (Bool, MCSession?) -> Void
    ) {
      let refusedBy = acceptedPeer.withLock { accepted -> String? in
        // A different peer is refused while the accepted one holds its
        // place: connected, or accepted so recently its connection may
        // still be forming. A stale unconnected claim expires, so a peer
        // that died before ever connecting cannot wedge the channel.
        if let held = accepted, held.peer.displayName != peerID.displayName,
          !session.connectedPeers.isEmpty
            || Date().timeIntervalSince(held.at) < Self.invitationTimeout
        {
          return held.peer.displayName
        }
        accepted = (peer: peerID, at: Date())
        return nil
      }
      if let refusedBy {
        trace("refused invitation from \(peerID.displayName), serving \(refusedBy)")
        invitationHandler(false, nil)
        return
      }
      trace("accepted invitation from \(peerID.displayName)")
      invitationHandler(true, session)
    }

    /// Reports a failed advertising start as a closed channel.
    public func advertiser(
      _: MCNearbyServiceAdvertiser,
      didNotStartAdvertisingPeer error: any Error
    ) {
      trace("advertising failed \(String(describing: error))")
      finish(.startup(String(describing: error)))
    }

    /// Invites the first advertised peer found.
    public func browser(
      _: MCNearbyServiceBrowser,
      foundPeer peerID: MCPeerID,
      withDiscoveryInfo _: [String: String]?
    ) {
      trace("found \(peerID.displayName)")
      lastFoundPeer.withLock { $0 = peerID }
      invite(peerID)
    }

    /// Forgets a vanished peer so a stale invite is not retried.
    public func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
      trace("lost \(peerID.displayName)")
      lastFoundPeer.withLock { found in
        if found?.displayName == peerID.displayName {
          found = nil
        }
      }
    }

    /// Reports a failed browsing start as a closed channel.
    public func browser(
      _: MCNearbyServiceBrowser,
      didNotStartBrowsingForPeers error: any Error
    ) {
      trace("browsing failed \(String(describing: error))")
      finish(.startup(String(describing: error)))
    }

    private func trace(_ message: String) {
      #if DEBUG
        print("[persistent-relay] \(message)")
        fflush(stdout)
      #endif
    }
  }
#endif
