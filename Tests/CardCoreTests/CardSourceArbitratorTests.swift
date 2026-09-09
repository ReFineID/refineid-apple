// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(CryptoTokenKit) && canImport(RappEngine)
  @testable import CardCore
  import CryptoTokenKit
  import Foundation
  import RappEngine
  import Testing

  @Suite("CardSourceArbitratorTests")
  internal struct CardSourceArbitratorTests {
    @Test("Returns .none when vault and reader are empty")
    internal func testEmptyState() async {
      let vault = RappDeviceVault(accessGroup: nil, servicePrefix: "fi.refineid.test.arb.empty")
      let source = await CardSourceArbitrator.resolveActiveSource(
        vault: vault,
        slotManager: nil
      )
      #expect(source == .none)
    }

    @Test("Returns .remoteRappPair when active pair is present and no reader connected")
    internal func testRemotePairFallback() async throws {
      let vault = RappDeviceVault(
        accessGroup: nil,
        servicePrefix: "fi.refineid.test.arb.remote.\(UUID().uuidString)"
      )
      let pairID = Data(repeating: 0x77, count: 16)
      let record = Data(repeating: 0x88, count: 32)
      try vault.insertPair(pairID: pairID, record: record)
      try vault.selectPair(pairID: pairID)

      let source = await CardSourceArbitrator.resolveActiveSource(
        vault: vault,
        slotManager: nil
      )
      #expect(source == .remoteRappPair(pairID: pairID))
    }
  }
#endif
