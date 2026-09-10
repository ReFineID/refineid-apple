// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security
import Testing

@testable import CardCore

#if canImport(RappEngine)
  import RappEngine
  @Suite
  internal struct RappAuthorizedOperationTests {

    // MARK: Functions

    @Test
    internal func authorizedBrowserAuthenticationExecutesOnceAndAcknowledgesResult() async throws {
      let fixture = try await RappIntegrationConnectionSupport.makePairedFixture()
      defer { RappIntegrationConnectionSupport.deleteKeychainServices(for: fixture) }
      let connection = try await RappIntegrationConnectionSupport.makeConnection(fixture)
      let digest = Data(repeating: 0xA5, count: 32)
      let signature = Data([0x30, 0x06, 0x02, 0x01, 0x01, 0x02, 0x01, 0x02])
      let operation = RappIntegrationFixtures.RequestedOperation.browserAuthentication(
        origin: "https://example.invalid",
        digest: digest
      )

      let requesterOutcome = Task {
        try await RappIntegrationConnectionSupport.awaitCompletion(
          connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await RappIntegrationAuthorizationSupport.authorizeAndComplete(
          connection.proxy, operation: operation, signature: signature)
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
          == RappIntegrationFixtures.ProxyProgress(
            prerequisites: 1,
            approvals: 1,
            executions: 1,
            acknowledgments: 1
          ))
      #expect(
        try fixture.proxyVault.loadProxy(
          pairID: fixture.proxySummary.pairID
        )
        .allSatisfy { $0.retainedResult == nil })
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
      let fixture = try await RappIntegrationConnectionSupport.makePairedFixture()
      defer { RappIntegrationConnectionSupport.deleteKeychainServices(for: fixture) }
      let connection = try await RappIntegrationConnectionSupport.makeConnection(fixture)
      let signature = Data([0x30, 0x06, 0x02, 0x01, 0x03, 0x02, 0x01, 0x04])
      let operation = RappIntegrationFixtures.RequestedOperation.documentSigning(
        documentName: "Review document.pdf",
        digest: Data(repeating: 0xC3, count: 32)
      )

      let requesterOutcome = Task {
        try await RappIntegrationConnectionSupport.awaitCompletion(
          connection.requester, operation: operation)
      }
      let proxyOutcome = Task {
        try await RappIntegrationAuthorizationSupport.authorizeAndComplete(
          connection.proxy, operation: operation, signature: signature)
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
          == RappIntegrationFixtures.ProxyProgress(
            prerequisites: 1,
            approvals: 1,
            executions: 1,
            acknowledgments: 1
          ))
      #expect(
        try fixture.proxyVault.loadProxy(
          pairID: fixture.proxySummary.pairID
        )
        .allSatisfy { $0.retainedResult == nil })
      #expect(
        try fixture.requesterVault.pairIsRevoked(
          pairID: fixture.requesterSummary.pairID) == false)
      #expect(
        try fixture.proxyVault.pairIsRevoked(
          pairID: fixture.proxySummary.pairID) == false)
      await connection.requester.close()
      await connection.proxy.close()
    }
  }
#endif
