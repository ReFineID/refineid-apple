// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security
import Testing

@testable import CardCore

#if canImport(RappEngine)
  import RappEngine
  @Suite
  internal struct RappIntegrationTests {
    // MARK: Nested Types

    internal struct ProxyProgress: Equatable {
      internal var prerequisites = 0
      internal var approvals = 0
      internal var executions = 0
      internal var acknowledgments = 0
    }

    internal enum ProxyTermination: CaseIterable, Sendable {
      case userDenied
      case retryPolicyRefused
      case cardRemovedBeforeTransmit
      case cardCompletionAmbiguous

      // MARK: Computed Properties

      internal var reason: RappOperationDriver.TerminalReason {
        switch self {
        case .userDenied:
          .userDenied

        case .retryPolicyRefused:
          .retryPolicyRefused

        case .cardRemovedBeforeTransmit:
          .cardRemovedBeforeTransmit

        case .cardCompletionAmbiguous:
          .cardCompletionAmbiguous
        }
      }

      internal var progress: ProxyProgress {
        switch self {
        case .userDenied:
          ProxyProgress(prerequisites: 1, approvals: 1)

        case .retryPolicyRefused:
          ProxyProgress(prerequisites: 1)

        case .cardRemovedBeforeTransmit:
          ProxyProgress(prerequisites: 1, approvals: 1)

        case .cardCompletionAmbiguous:
          ProxyProgress(prerequisites: 1, approvals: 1, executions: 1)
        }
      }

      internal var proxyTransportCloseCount: Int {
        switch self {
        case .retryPolicyRefused, .cardCompletionAmbiguous:
          1

        case .userDenied, .cardRemovedBeforeTransmit:
          0
        }
      }
    }

    private enum TestFailure: Error {
      case receiverMissing
      case pairingClosed(RappPairingCoordinator.CloseReason)
      case pairingEndedWithoutRecord
      case connectionClosed(RappConnectionCoordinator.CloseReason)
      case operationEndedWithoutResult
      case operationTerminated(RappOperationDriver.TerminalReason?)
      case unexpectedConnectionEvent
      case unexpectedTransportError
    }

    private struct PairingFixture {
      let requesterVault: RappDeviceVault
      let proxyVault: RappDeviceVault
      let requesterSummary: RappPairingCoordinator.PairSummary
      let proxySummary: RappPairingCoordinator.PairSummary
      let requesterFrames: (frames: [Data], closeCount: Int)
      let proxyFrames: (frames: [Data], closeCount: Int)
      let requesterPrefix: String
      let proxyPrefix: String
    }

    private struct ConnectionFixture {
      let requester: RappConnectionCoordinator
      let proxy: RappConnectionCoordinator
      let requesterOutbound: FrameEndpoint
      let proxyOutbound: FrameEndpoint
    }

    private enum RequestedOperation: Sendable, Equatable {
      case browserAuthentication(
        origin: String,
        digest:
          Data)
      case documentSigning(
        documentName: String,
        digest:
          Data)

      // MARK: Computed Properties

      var kind: RappOperationDriver.OperationKind {
        switch self {
        case .browserAuthentication:
          .browserAuthenticate

        case .documentSigning:
          .signDocument
        }
      }

      var displayContext: String {
        switch self {
        case .browserAuthentication(let origin, _):
          origin

        case .documentSigning(let documentName, _):
          documentName
        }
      }

      var digest: Data {
        switch self {
        case .browserAuthentication(_, let digest), .documentSigning(_, let digest):
          digest
        }
      }

      // MARK: Functions

      func begin(on coordinator: RappConnectionCoordinator) async throws {
        switch self {
        case .browserAuthentication(let origin, let digest):
          try await coordinator.beginBrowserAuthentication(
            origin: origin,
            keyProfile: .ecdsaP256,
            algorithm: .ecdsaSHA256,
            digest: digest,
            expiresAfterMilliseconds: 60_000
          )

        case .documentSigning(let documentName, let digest):
          try await coordinator.beginSignDocument(
            documentName: documentName,
            keyProfile: .ecdsaP256,
            algorithm: .ecdsaSHA256,
            digest: digest,
            expiresAfterMilliseconds: 60_000
          )
        }
      }

      func matches(_ operation: RappOperationDriver.Operation) -> Bool {
        operation.kind == kind
          && operation.displayContext == displayContext
          && operation.keyProfile == .ecdsaP256
          && operation.algorithm == .ecdsaSHA256
          && operation.digest == digest
      }
    }

    private actor FrameEndpoint {
      // MARK: Nested Types

      typealias Receiver = @Sendable (Data) async -> Void

      // MARK: Properties

      private var receiver: Receiver?
      private var frames: [Data] = []
      private var closeCount = 0

      // MARK: Functions

      func install(_ receiver: @escaping Receiver) {
        self.receiver = receiver
      }

      /// Hands the frame to the peer without waiting for it to be processed.
      ///
      /// A real transport returns once the frame is on its way. Delivering
      /// it inline instead suspends the sender inside its own coordinator
      /// until the peer has finished, so a reply that arrives during that
      /// window waits for an actor the sender still holds and neither side
      /// moves again. The peers are two actors here, and every exchange in
      /// this protocol is a reply.
      func send(_ frame: Data) async throws {
        frames.append(frame)
        guard let receiver else { throw TestFailure.receiverMissing }
        Task { await receiver(frame) }
        // Lets the delivery above begin before the sender continues, which
        // is the ordering a real transport gives without being asked.
        await Task.yield()
      }

      func close() {
        closeCount += 1
      }

      func snapshot() -> (frames: [Data], closeCount: Int) {
        (frames, closeCount)
      }
    }

    private actor TransportRecorder {
      // MARK: Properties

      private var frames: [Data] = []
      private var closeCount = 0

      // MARK: Functions

      func record(_ frame: Data) {
        frames.append(frame)
      }

      func close() {
        closeCount += 1
      }

      func snapshot() -> (frames: [Data], closeCount: Int) {
        (frames, closeCount)
      }
    }

    // MARK: Static Properties

    private static let profiles = [
      "fi.refineid.card-status.v1",
      "fi.refineid.authentication.v1",
      "fi.refineid.document-signing.v1",
    ]
    private static let transportProfile = "apple-peer-v1"
    private static let candidateID = "apple-peer-v1.nearby"
    private static let liveness = RappOperationDriver.Liveness(
      baseIntervalMilliseconds: 60_000,
      responseTimeoutMilliseconds: 10_000,
      maximumIntervalMilliseconds: 60_000,
      maximumJitterMilliseconds: 0,
      maximumMisses: 3
    )

    // MARK: Static Functions

    private static func makePairedFixture() async throws -> PairingFixture {
      let testID = UUID().uuidString
      let requesterPrefix = "fi.refineid.tests.rapp.\(testID).requester"
      let proxyPrefix = "fi.refineid.tests.rapp.\(testID).proxy"
      let requesterVault = RappDeviceVault(
        accessGroup: nil,
        servicePrefix: requesterPrefix
      )
      let proxyVault = RappDeviceVault(
        accessGroup: nil,
        servicePrefix: proxyPrefix
      )
      let requesterOutbound = FrameEndpoint()
      let proxyOutbound = FrameEndpoint()
      let requesterTransport = RappClosureFrameTransport(
        sender: { frame in try await requesterOutbound.send(frame) },
        closer: { await requesterOutbound.close() }
      )
      let proxyTransport = RappClosureFrameTransport(
        sender: { frame in try await proxyOutbound.send(frame) },
        closer: { await proxyOutbound.close() }
      )
      let requester = try RappPairingCoordinator.requester(
        profiles: profiles,
        candidates: [
          .init(
            profile: transportProfile,
            candidateID: candidateID,
            parametersCBOR: Data([0xA0])
          )
        ],
        selectedCandidateID: candidateID,
        offerLifetimeMilliseconds: 60_000,
        displayName: "Requester Mac",
        platform: "macOS",
        vault: requesterVault,
        transport: requesterTransport
      )
      let proxy = try RappPairingCoordinator.proxy(
        scannedOfferURI: try #require(requester.offerURI),
        selectedCandidateID: candidateID,
        displayName: "Authorizer iPhone",
        platform: "iOS",
        vault: proxyVault,
        transport: proxyTransport
      )
      await requesterOutbound.install { frame in await proxy.receive(frame) }
      await proxyOutbound.install { frame in await requester.receive(frame) }

      let requesterOutcome = Task {
        try await approveAndAwaitPair(requester, profiles: profiles)
      }
      let proxyOutcome = Task {
        try await approveAndAwaitPair(proxy, profiles: profiles)
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await proxy.transportConnected()
      await requester.transportConnected()
      return try await PairingFixture(
        requesterVault: requesterVault,
        proxyVault: proxyVault,
        requesterSummary: requesterOutcome.value,
        proxySummary: proxyOutcome.value,
        requesterFrames: requesterOutbound.snapshot(),
        proxyFrames: proxyOutbound.snapshot(),
        requesterPrefix: requesterPrefix,
        proxyPrefix: proxyPrefix
      )
    }

    /// What the shipped requester actually runs with.
    ///
    /// The suite's own liveness never fires inside a test, so every path
    /// below was measured with no probe in flight. A card read takes
    /// several seconds of antenna time, which is longer than this
    /// interval, so on a device a probe is always in flight while an
    /// operation is executing -- the one arrangement the fast fixture
    /// could not produce.
    private static let interactiveLiveness = RappOperationDriver.Liveness(
      baseIntervalMilliseconds: 5_000,
      responseTimeoutMilliseconds: 3_000,
      maximumIntervalMilliseconds: 60_000,
      maximumJitterMilliseconds: 500,
      maximumMisses: 3
    )

    private static func makeConnection(
      _ fixture: PairingFixture,
      liveness: RappOperationDriver.Liveness = liveness
    ) async throws -> ConnectionFixture {
      let requesterPair = try RappPairRecord.loadFromVault(
        pairId: fixture.requesterSummary.pairID,
        vault: fixture.requesterVault
      )
      let proxyPair = try RappPairRecord.loadFromVault(
        pairId: fixture.proxySummary.pairID,
        vault: fixture.proxyVault
      )
      let requesterOutbound = FrameEndpoint()
      let proxyOutbound = FrameEndpoint()
      let requester = try RappConnectionCoordinator(
        role: .requester,
        pair: requesterPair,
        vault: fixture.requesterVault,
        transport: RappClosureFrameTransport(
          sender: { frame in try await requesterOutbound.send(frame) },
          closer: { await requesterOutbound.close() }
        ),
        maximumLifetimeMilliseconds: 60_000,
        liveness: liveness
      )
      let proxy = try RappConnectionCoordinator(
        role: .proxy,
        pair: proxyPair,
        vault: fixture.proxyVault,
        transport: RappClosureFrameTransport(
          sender: { frame in try await proxyOutbound.send(frame) },
          closer: { await proxyOutbound.close() }
        ),
        maximumLifetimeMilliseconds: 60_000,
        liveness: liveness
      )
      await requesterOutbound.install { frame in await proxy.receive(frame) }
      await proxyOutbound.install { frame in await requester.receive(frame) }
      return ConnectionFixture(
        requester: requester,
        proxy: proxy,
        requesterOutbound: requesterOutbound,
        proxyOutbound: proxyOutbound
      )
    }

    private static func awaitCompletion(
      _ coordinator: RappConnectionCoordinator,
      operation: RequestedOperation
    ) async throws -> RappOperationDriver.Result {
      for await event in coordinator.events {
        switch event {
        case .established:
          try await operation.begin(on: coordinator)

        case .completed(_, let result):
          return result

        case .terminal(_, _, let reason):
          throw TestFailure.operationTerminated(reason)

        case .closed(let reason):
          throw TestFailure.connectionClosed(reason)

        case .inspectPrerequisites, .awaitUserApproval, .executeSafeRead,
          .executeCardCommand, .advisoryCancellation, .operationFinished,
          .peerBusy, .peerUnknownOperation:
          throw TestFailure.unexpectedConnectionEvent
        }
      }
      throw TestFailure.operationEndedWithoutResult
    }

    private static func awaitTerminal(
      _ coordinator: RappConnectionCoordinator,
      operation: RequestedOperation
    ) async throws -> RappOperationDriver.TerminalReason? {
      for await event in coordinator.events {
        switch event {
        case .established:
          try await operation.begin(on: coordinator)

        case .terminal(_, _, let reason):
          return reason

        case .closed(let reason):
          throw TestFailure.connectionClosed(reason)

        case .inspectPrerequisites, .awaitUserApproval, .executeSafeRead,
          .executeCardCommand, .completed, .advisoryCancellation,
          .operationFinished, .peerBusy, .peerUnknownOperation:
          throw TestFailure.unexpectedConnectionEvent
        }
      }
      throw TestFailure.operationEndedWithoutResult
    }

    private static func authorizeAndComplete(
      _ coordinator: RappConnectionCoordinator,
      operation expected: RequestedOperation,
      signature: Data,
      cardHoldMilliseconds: UInt64 = 0
    ) async throws -> ProxyProgress {
      var progress = ProxyProgress()
      for await event in coordinator.events {
        switch event {
        case .established:
          break

        case .inspectPrerequisites(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.prerequisites += 1
          try await coordinator.prerequisitesComplete(operationID: operationID)

        case .awaitUserApproval(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.approvals += 1
          try await coordinator.approve(operationID: operationID)

        case .executeCardCommand(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.executions += 1
          // The antenna's share of the operation, where the proxy is busy
          // with the card and answers nothing else.
          if cardHoldMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(cardHoldMilliseconds))
          }
          try await coordinator.completeSignature(
            operationID: operationID,
            signature: signature
          )

        case .operationFinished:
          progress.acknowledgments += 1
          return progress

        case .terminal(_, _, let reason):
          throw TestFailure.operationTerminated(reason)

        case .closed(let reason):
          throw TestFailure.connectionClosed(reason)

        case .executeSafeRead, .completed, .advisoryCancellation,
          .peerBusy, .peerUnknownOperation:
          throw TestFailure.unexpectedConnectionEvent
        }
      }
      throw TestFailure.operationEndedWithoutResult
    }

    private static func authorizeAndRejectCredential(
      _ coordinator: RappConnectionCoordinator,
      operation expected: RequestedOperation
    ) async throws -> ProxyProgress {
      var progress = ProxyProgress()
      for await event in coordinator.events {
        switch event {
        case .established:
          break

        case .inspectPrerequisites(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.prerequisites += 1
          try await coordinator.prerequisitesComplete(operationID: operationID)

        case .awaitUserApproval(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.approvals += 1
          try await coordinator.approve(operationID: operationID)

        case .executeCardCommand(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.executions += 1
          try await coordinator.credentialRejected(operationID: operationID)
          return progress

        case .terminal(_, _, let reason):
          throw TestFailure.operationTerminated(reason)

        case .closed(let reason):
          throw TestFailure.connectionClosed(reason)

        case .executeSafeRead, .completed, .advisoryCancellation,
          .operationFinished, .peerBusy, .peerUnknownOperation:
          throw TestFailure.unexpectedConnectionEvent
        }
      }
      throw TestFailure.operationEndedWithoutResult
    }

    private static func authorizeAndTerminate(
      _ coordinator: RappConnectionCoordinator,
      operation expected: RequestedOperation,
      termination: ProxyTermination
    ) async throws -> ProxyProgress {
      var progress = ProxyProgress()
      for await event in coordinator.events {
        switch event {
        case .established:
          break

        case .inspectPrerequisites(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.prerequisites += 1
          if termination == .retryPolicyRefused {
            try await coordinator.retryRefused(operationID: operationID)
            return progress
          }
          try await coordinator.prerequisitesComplete(operationID: operationID)

        case .awaitUserApproval(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          progress.approvals += 1
          if termination == .userDenied {
            try await coordinator.deny(operationID: operationID)
            return progress
          }
          try await coordinator.approve(operationID: operationID)

        case .executeCardCommand(let operationID, let operation):
          guard expected.matches(operation) else {
            throw TestFailure.unexpectedConnectionEvent
          }
          switch termination {
          case .cardRemovedBeforeTransmit:
            try await coordinator.cardRemovedBeforeTransmit(operationID: operationID)

          case .cardCompletionAmbiguous:
            progress.executions += 1
            try await coordinator.cardCompletionAmbiguous(operationID: operationID)

          case .userDenied, .retryPolicyRefused:
            throw TestFailure.unexpectedConnectionEvent
          }
          return progress

        case .terminal(_, _, let reason):
          throw TestFailure.operationTerminated(reason)

        case .closed(let reason):
          throw TestFailure.connectionClosed(reason)

        case .executeSafeRead, .completed, .advisoryCancellation,
          .operationFinished, .peerBusy, .peerUnknownOperation:
          throw TestFailure.unexpectedConnectionEvent
        }
      }
      throw TestFailure.operationEndedWithoutResult
    }

    private static func approveAndAwaitPair(
      _ coordinator: RappPairingCoordinator,
      profiles: [String]
    ) async throws -> RappPairingCoordinator.PairSummary {
      for await event in coordinator.events {
        switch event {
        case .reviewPeer:
          await coordinator.approve(grantedProfiles: profiles)

        case .paired(let summary):
          return summary

        case .closed(let reason):
          throw TestFailure.pairingClosed(reason)

        case .offerReady, .offerRestored:
          break
        }
      }
      throw TestFailure.pairingEndedWithoutRecord
    }

    private static func deleteKeychainServices(for fixture: PairingFixture) {
      deleteKeychainServices(
        prefix: fixture.requesterPrefix,
        pairID: fixture.requesterSummary.pairID
      )
      deleteKeychainServices(
        prefix: fixture.proxyPrefix,
        pairID: fixture.proxySummary.pairID
      )
    }

    private static func deleteKeychainServices(prefix: String, pairID: Data) {
      let pairHex = pairID.map { String(format: "%02x", $0) }.joined()
      for suffix in [
        "pair",
        "selection",
        "requester.\(pairHex)",
        "proxy.\(pairHex)",
      ] {
        let query: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: "\(prefix).\(suffix)",
          kSecUseDataProtectionKeychain as String: KeychainPlatform.usesDataProtection,
          kSecAttrSynchronizable as String: false,
        ]
        SecItemDelete(query as CFDictionary)
      }
    }

    // MARK: Functions

    @Test
    internal func closureTransportPreservesFramesAndClosesExactlyOnce() async throws {
      let recorder = TransportRecorder()
      let transport = RappClosureFrameTransport(
        sender: { frame in await recorder.record(frame) },
        closer: { await recorder.close() }
      )
      let frame = Data([0x01, 0x02, 0x03])

      try await transport.send(frame)
      await transport.close()
      await transport.close()

      let snapshot = await recorder.snapshot()
      #expect(snapshot.frames == [frame])
      #expect(snapshot.closeCount == 1)

      do {
        try await transport.send(Data([0x04]))
        Issue.record("A closed RAPP transport accepted another frame")
      } catch is CancellationError {
        // Expected: a closed transport cannot silently reopen.
      } catch {
        Issue.record("A closed RAPP transport returned the wrong error")
      }
    }

    @Test
    internal func cardOperationMappingsAreCompleteAndRoundTrip() throws {
      let profiles: [CardKeyProfile] = [
        .ecdsaP256,
        .ecdsaP384,
        .rsa2048,
        .rsa3072,
      ]
      for profile in profiles {
        #expect(RappOperationDriver.KeyProfile(profile).cardKeyProfile == profile)
      }

      let algorithms = [
        SigningAlgorithm(hash: .sha224, scheme: .ecdsa),
        SigningAlgorithm(hash: .sha256, scheme: .ecdsa),
        SigningAlgorithm(hash: .sha384, scheme: .ecdsa),
        SigningAlgorithm(hash: .sha512, scheme: .ecdsa),
        SigningAlgorithm(hash: .sha256, scheme: .rsaPkcs1),
        SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        SigningAlgorithm(hash: .sha512, scheme: .rsaPkcs1),
        SigningAlgorithm(hash: .sha256, scheme: .rsaPss),
      ]
      for algorithm in algorithms {
        let mapped = try #require(RappOperationDriver.SignatureAlgorithm(algorithm))
        #expect(mapped.signingAlgorithm.hash == algorithm.hash)
        #expect(mapped.signingAlgorithm.scheme == algorithm.scheme)
      }

      #expect(
        RappOperationDriver.SignatureAlgorithm(
          SigningAlgorithm(hash: .sha224, scheme: .rsaPkcs1)
        ) == nil)
      #expect(
        RappOperationDriver.SignatureAlgorithm(
          SigningAlgorithm(hash: .sha384, scheme: .rsaPss)
        ) == nil)
    }

    @Test
    internal func swiftCoordinatorsPairThroughRustAndRevocationRemovesThePair() async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }

      #expect(fixture.requesterSummary.pairID == fixture.proxySummary.pairID)
      #expect(fixture.requesterSummary.role == .requester)
      #expect(fixture.proxySummary.role == .proxy)
      #expect(Set(fixture.requesterSummary.profiles) == Set(Self.profiles))
      #expect(Set(fixture.proxySummary.profiles) == Set(Self.profiles))
      #expect(fixture.requesterSummary.transportProfile == Self.transportProfile)
      #expect(fixture.requesterSummary.candidateID == Self.candidateID)
      #expect(
        try fixture.requesterVault.loadPair(
          pairID: fixture.requesterSummary.pairID) != nil)
      #expect(try fixture.proxyVault.loadPair(pairID: fixture.proxySummary.pairID) != nil)

      #expect(!fixture.requesterFrames.frames.isEmpty)
      #expect(!fixture.proxyFrames.frames.isEmpty)
      #expect(fixture.requesterFrames.closeCount == 1)
      #expect(fixture.proxyFrames.closeCount == 1)

      let catalog = RappPairCatalog(vault: fixture.requesterVault)
      try await catalog.select(pairID: fixture.requesterSummary.pairID)
      #expect(try await catalog.selectedPair()?.pairID == fixture.requesterSummary.pairID)
      try await catalog.revoke(pairID: fixture.requesterSummary.pairID)
      #expect(
        try fixture.requesterVault.loadPair(
          pairID: fixture.requesterSummary.pairID) == nil)
      #expect(try await catalog.activePairs().isEmpty)
      #expect(try await catalog.selectedPair() == nil)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
    }

    @Test
    internal func authorizedBrowserAuthenticationExecutesOnceAndAcknowledgesResult() async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }
      let connection = try await Self.makeConnection(fixture)
      let digest = Data(repeating: 0xA5, count: 32)
      let signature = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])
      let operation = RequestedOperation.browserAuthentication(
        origin: "https://example.invalid",
        digest: digest
      )

      let requesterOutcome = Task {
        try await Self.awaitCompletion(connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await Self.authorizeAndComplete(
          connection.proxy,
          operation: operation,
          signature: signature
        )
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await connection.proxy.start()
      await connection.requester.start()
      let result = try await requesterOutcome.value
      let progress = try await proxyOutcome.value

      #expect(result.kind == .signature)
      #expect(result.bytes == signature)
      #expect(
        progress
          == ProxyProgress(
            prerequisites: 1,
            approvals: 1,
            executions: 1,
            acknowledgments: 1
          ))
      #expect(
        try fixture.proxyVault.loadProxy(
          pairID: fixture.proxySummary.pairID
        ).allSatisfy { $0.retainedResult == nil })
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      await connection.requester.close()
      await connection.proxy.close()
    }

    /// A card command that outlasts the liveness interval must still land.
    ///
    /// The antenna needs seconds and the requester probes every five, so a
    /// probe crosses the wire while the proxy is still holding the card.
    /// Neither peer may treat that crossing as a reason to end the pairing:
    /// a holder who presented a card slightly slowly would be told to scan
    /// a fresh code, and the pairing they had would be gone.
    @Test
    internal func aCardCommandOutlastingLivenessKeepsTheSessionAndPairing() async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }
      let connection = try await Self.makeConnection(
        fixture,
        liveness: Self.interactiveLiveness
      )
      let signature = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])
      let operation = RequestedOperation.browserAuthentication(
        origin: "https://example.invalid",
        digest: Data(repeating: 0xA5, count: 32)
      )

      let requesterOutcome = Task {
        try await Self.awaitCompletion(connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await Self.authorizeAndComplete(
          connection.proxy,
          operation: operation,
          signature: signature,
          cardHoldMilliseconds: 7_000
        )
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await connection.proxy.start()
      await connection.requester.start()
      let result = try await requesterOutcome.value
      _ = try await proxyOutcome.value

      #expect(result.kind == .signature)
      #expect(result.bytes == signature)
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      await connection.requester.close()
      await connection.proxy.close()
    }

    @Test
    internal func authorizedDocumentSigningExecutesOnceAndAcknowledgesResult() async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }
      let connection = try await Self.makeConnection(fixture)
      let signature = Data([0x30, 0x06, 0x02, 0x01, 0x03, 0x02, 0x01, 0x04])
      let operation = RequestedOperation.documentSigning(
        documentName: "Review document.pdf",
        digest: Data(repeating: 0xC3, count: 32)
      )

      let requesterOutcome = Task {
        try await Self.awaitCompletion(connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await Self.authorizeAndComplete(
          connection.proxy,
          operation: operation,
          signature: signature
        )
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await connection.proxy.start()
      await connection.requester.start()
      let result = try await requesterOutcome.value
      let progress = try await proxyOutcome.value

      #expect(result.kind == .signature)
      #expect(result.bytes == signature)
      #expect(
        progress
          == ProxyProgress(
            prerequisites: 1,
            approvals: 1,
            executions: 1,
            acknowledgments: 1
          ))
      #expect(
        try fixture.proxyVault.loadProxy(
          pairID: fixture.proxySummary.pairID
        ).allSatisfy { $0.retainedResult == nil })
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      await connection.requester.close()
      await connection.proxy.close()
    }

    @Test(arguments: ProxyTermination.allCases)
    internal func nonCredentialTerminalPathsRespectCommandBoundaryAndPreservePairing(
      termination: ProxyTermination
    ) async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }
      let connection = try await Self.makeConnection(fixture)
      let operation = RequestedOperation.browserAuthentication(
        origin: "https://terminal.example.invalid",
        digest: Data(repeating: UInt8(termination.hashValue & 0xFF), count: 32)
      )

      let requesterOutcome = Task {
        try await Self.awaitTerminal(connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await Self.authorizeAndTerminate(
          connection.proxy,
          operation: operation,
          termination: termination
        )
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await connection.proxy.start()
      await connection.requester.start()
      let reason = try await requesterOutcome.value
      let progress = try await proxyOutcome.value

      #expect(reason == termination.reason)
      #expect(progress == termination.progress)
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      #expect(
        await connection.proxyOutbound.snapshot().closeCount
          == termination.proxyTransportCloseCount)

      await connection.requester.close()
      await connection.proxy.close()
    }

    @Test
    internal func credentialRejectionRevokesBothPeersWithoutAnotherExecution() async throws {
      let fixture = try await Self.makePairedFixture()
      defer { Self.deleteKeychainServices(for: fixture) }
      let connection = try await Self.makeConnection(fixture)
      let digest = Data(repeating: 0x5A, count: 32)
      let operation = RequestedOperation.browserAuthentication(
        origin: "https://example.invalid",
        digest: digest
      )

      let requesterOutcome = Task {
        try await Self.awaitTerminal(connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await Self.authorizeAndRejectCredential(
          connection.proxy,
          operation: operation
        )
      }
      defer {
        requesterOutcome.cancel()
        proxyOutcome.cancel()
      }

      await connection.proxy.start()
      await connection.requester.start()
      let reason = try await requesterOutcome.value
      let progress = try await proxyOutcome.value

      #expect(reason == .credentialRejected)
      #expect(
        progress
          == ProxyProgress(
            prerequisites: 1,
            approvals: 1,
            executions: 1,
            acknowledgments: 0
          ))
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      #expect(
        try fixture.requesterVault.loadPair(
          pairID: fixture.requesterSummary.pairID) == nil)
      #expect(try fixture.proxyVault.loadPair(pairID: fixture.proxySummary.pairID) == nil)
      #expect(try fixture.requesterVault.activePairIDs().isEmpty)
      #expect(try fixture.proxyVault.activePairIDs().isEmpty)
    }
  }
#endif
