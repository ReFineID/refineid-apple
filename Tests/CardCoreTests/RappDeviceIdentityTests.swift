// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Testing

@testable import CardCore

@Suite("RappDeviceIdentityTests")
internal struct RappDeviceIdentityTests {
  @Test("Creates and preserves stable key and identifier with fixed seed")
  internal func testFixedKeyIdentity() throws {
    let fixedPrivateKey = Data(repeating: 0x42, count: 32)
    let fixedUUID = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()

    let identity = try RappDeviceIdentity(
      accessGroup: nil,
      service: "fi.refineid.test.identity",
      deviceName: "Test Mac",
      modelName: "MacBookPro18,1",
      fixedPrivateKey: fixedPrivateKey,
      fixedDeviceID: fixedUUID
    )

    #expect(identity.deviceID == fixedUUID)
    #expect(identity.deviceName == "Test Mac")
    #expect(identity.modelName == "MacBookPro18,1")
    #expect(identity.privateKeyData == fixedPrivateKey)
    #expect(identity.publicKeyData.count == 32)

    let curveKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: fixedPrivateKey)
    #expect(identity.publicKeyData == curveKey.publicKey.rawRepresentation)
  }

  @Test("Rejects malformed private key data")
  internal func testMalformedKeyRejection() {
    let badKey = Data(repeating: 0x01, count: 16)
    let uuid = UUID()

    #expect(throws: RappDeviceIdentity.Failure.malformedKey) {
      _ = try RappDeviceIdentity(
        accessGroup: nil,
        service: "fi.refineid.test.identity",
        deviceName: "Bad Key Device",
        modelName: "Model",
        fixedPrivateKey: badKey,
        fixedDeviceID: uuid
      )
    }
  }

  @Test("Resolves friendly marketing names from device model identifiers dynamically")
  internal func testFriendlyMarketingName() {
    #if canImport(UniformTypeIdentifiers)
      #expect(RappDeviceIdentity.friendlyMarketingName(from: "iPhone16,1") == "iPhone 15 Pro")
      #expect(RappDeviceIdentity.friendlyMarketingName(from: "iPhone16,2") == "iPhone 15 Pro Max")
      #expect(
        RappDeviceIdentity.friendlyMarketingName(from: "   iPhone16,2  \n") == "iPhone 15 Pro Max")
      #expect(RappDeviceIdentity.friendlyMarketingName(from: "") == nil)
      #expect(RappDeviceIdentity.friendlyMarketingName(from: "NonExistentModel99,99") == nil)
    #endif
  }
}
