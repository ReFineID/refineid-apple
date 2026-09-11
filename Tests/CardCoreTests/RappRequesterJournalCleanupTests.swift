// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import XCTest

@testable import CardCore

/// One requester journal is deletable without touching its pair's others.
internal final class RappRequesterJournalCleanupTests: XCTestCase {
  private static let prefix = "test.rapp.requester-cleanup"

  private func makeVault() -> RappDeviceVault {
    RappDeviceVault(accessGroup: nil, servicePrefix: Self.prefix)
  }

  private func identifiers(pair: UInt8, operation: UInt8) -> (Data, Data) {
    (
      Data(repeating: pair, count: RappDeviceVault.IdentifierSize.pair),
      Data(repeating: operation, count: RappDeviceVault.IdentifierSize.operation)
    )
  }

  /// Removing one operation's journal leaves the pair's other journals
  /// stored, and removing twice is not an error.
  internal func testRemoveRequesterDeletesOnlyItsOperation() throws {
    let vault = makeVault()
    let (pairID, firstOperation) = identifiers(pair: 0x31, operation: 0x41)
    let (_, secondOperation) = identifiers(pair: 0x31, operation: 0x42)
    try vault.persistRequester(
      pairID: pairID, operationID: firstOperation, record: Data([0x01]))
    try vault.persistRequester(
      pairID: pairID, operationID: secondOperation, record: Data([0x02]))

    try vault.removeRequester(pairID: pairID, operationID: firstOperation)

    XCTAssertEqual(try vault.loadRequester(pairID: pairID), [Data([0x02])])
    XCTAssertNoThrow(
      try vault.removeRequester(pairID: pairID, operationID: firstOperation))
  }

  /// The namespace wipe deletes every item under the prefix across the
  /// vault's services, leaves lookalike and foreign services alone, and
  /// refuses an empty prefix.
  internal func testDeleteServiceNamespace() throws {
    let vault = RappDeviceVault(
      accessGroup: nil, servicePrefix: "fi.refineid.test.namespace-wipe")
    let (pairID, operationID) = identifiers(pair: 0x33, operation: 0x44)
    try vault.insertPair(pairID: pairID, record: Data([0x01]))
    try vault.persistRequester(
      pairID: pairID, operationID: operationID, record: Data([0x02]))
    try vault.persistProxy(
      pairID: pairID, operationID: operationID, record: Data([0x03]))
    try vault.selectPair(pairID: pairID)
    vault.inMemoryStore["unrelated.service"] = ["acc": [:]]
    vault.inMemoryStore["fi.refined.lookalike"] = ["acc": [:]]

    let deleted = try vault.deleteServiceNamespace()

    XCTAssertEqual(deleted, 4)
    XCTAssertNil(try vault.loadPair(pairID: pairID))
    XCTAssertEqual(try vault.loadRequester(pairID: pairID), [])
    XCTAssertEqual(vault.inMemoryStore["unrelated.service"]?.count, 1)
    XCTAssertEqual(vault.inMemoryStore["fi.refined.lookalike"]?.count, 1)
    XCTAssertThrowsError(try vault.deleteServiceNamespace(""))
  }
}
