// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite("RAPP shipping configuration")
internal struct RappShippingConfigurationTests {
  // MARK: Static Properties

  private static let classID = "fi.refineid.ReFineID.rapp-token"
  private static let service = "_refineid-rly._tcp"

  // MARK: Static Computed Properties

  private static var root: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  // MARK: Static Functions

  private static func plist(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: root.appending(path: path))
    return try #require(
      PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any])
  }

  private static func extensionAttributes(
    _ plist: [String: Any]
  ) -> [String: Any]? {
    (plist["NSExtension"] as? [String: Any])?["NSExtensionAttributes"]
      as? [String: Any]
  }

  // MARK: Functions

  @Test("RAPP and smart-card drivers have separate CryptoTokenKit classes")
  internal func separateTokenDrivers() throws {
    #expect(PersistentTokenIdentity.classID == Self.classID)

    let reader = try Self.plist("Config/TokenExtension-Info.plist")
    let rapp = try Self.plist("Config/RappTokenExtension-Info.plist")
    let readerAttributes = try #require(Self.extensionAttributes(reader))
    let rappAttributes = try #require(Self.extensionAttributes(rapp))
    #expect(readerAttributes["com.apple.ctk.class-id"] as? String == "fi.refineid.ReFineID.token")
    #expect(
      readerAttributes["com.apple.ctk.driver-class"] as? String
        == "ReFineIDTokenExtension.TokenDriver")
    #expect(readerAttributes["com.apple.ctk.token-type"] as? String == "smartcard")
    #expect(rappAttributes["com.apple.ctk.class-id"] as? String == Self.classID)
    #expect(
      rappAttributes["com.apple.ctk.driver-class"] as? String
        == "$(PRODUCT_MODULE_NAME).PersistentTokenDriver")
    #expect(rappAttributes["com.apple.ctk.token-type"] == nil)
  }

  @Test("RAPP extension is a distinct embedded product on every platform")
  internal func separateRappExtensionTarget() throws {
    let project = try String(
      contentsOf: Self.root.appending(path: "ReFineID.xcodeproj/project.pbxproj"),
      encoding: .utf8)
    #expect(project.contains("ReFineIDRappTokenExtension"))
    #expect(project.contains(Self.classID))
    #expect(project.contains("RappTokenExtension"))
    #expect(project.contains("Config/RappTokenExtension-iOS.entitlements"))
    #expect(!project.contains("ReFineIDRappTokenExtension.appex */; platformFilters"))
  }

  @Test("Shipping configurations gate the remote card out of the iOS app")
  internal func shippingConfigurationsGateRemoteCard() throws {
    let project = try String(
      contentsOf: Self.root.appending(path: "ReFineID.xcodeproj/project.pbxproj"),
      encoding: .utf8)
    // The RAPP extension is excluded from the embed phase of both
    // shipping configurations, and both point the iOS app at the store
    // Info.plist that carries no local-network declarations.
    func occurrences(of needle: String) -> Int {
      project.components(separatedBy: needle).count - 1
    }
    #expect(occurrences(of: "ReFineIDRappTokenExtension.appex,") == 2)
    #expect(
      occurrences(
        of: "INFOPLIST_FILE = \"Config/ReFineID-iOS-Store-Info.plist\";") == 2)

    // The macOS store shape mirrors the iOS one: both shipping
    // configurations point the Mac app at the store Info.plist and
    // entitlements without the remote card's declarations, while Debug
    // and Profile keep the development files.
    #expect(
      occurrences(
        of: "\"INFOPLIST_FILE[sdk=macosx*]\" = \"Config/ReFineID-Store-Info.plist\";") == 2)
    #expect(
      occurrences(
        of: "\"INFOPLIST_FILE[sdk=macosx*]\" = \"Config/ReFineID-Info.plist\";") == 2)
    #expect(
      occurrences(
        of: "\"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]\" = \"Config/ReFineID-Store.entitlements\";")
        == 2)
    #expect(
      occurrences(
        of: "\"CODE_SIGN_ENTITLEMENTS[sdk=macosx*]\" = Config/ReFineID.entitlements;") == 2)

    let features = try String(
      contentsOf: Self.root.appending(path: "Config/Features.xcconfig"),
      encoding: .utf8)
    #expect(features.contains("REFINEID_REMOTE_CARD_FEATURE = REFINEID_REMOTE_CARD"))
    #expect(
      features.contains("REFINEID_REMOTE_CARD_FEATURE[config=TestFlight] = REFINEID_REMOTE_CARD"))
    #expect(
      features.contains("REFINEID_REMOTE_CARD_FEATURE[config=Release] = REFINEID_REMOTE_CARD"))

    // Activation is enabled across configurations.
    #expect(features.contains("REFINEID_ACTIVATION_FEATURE = FEATURE_CARD_ACTIVATION"))
    #expect(
      features.contains("REFINEID_ACTIVATION_FEATURE[config=TestFlight] = FEATURE_CARD_ACTIVATION"))
    #expect(
      features.contains("REFINEID_ACTIVATION_FEATURE[config=Release] = FEATURE_CARD_ACTIVATION"))
  }

  @Test("The store Info.plist differs from development by exactly the gates")
  internal func storeInfoPlistShape() throws {
    let development = try Self.plist("Config/ReFineID-iOS-Info.plist")
    let store = try Self.plist("Config/ReFineID-iOS-Store-Info.plist")

    let storeNfcUsage = try #require(store["NFCReaderUsageDescription"] as? String)
    let developmentNfcUsage = try #require(development["NFCReaderUsageDescription"] as? String)
    #expect(!storeNfcUsage.localizedCaseInsensitiveContains("activation"))
    #expect(developmentNfcUsage.localizedCaseInsensitiveContains("activation"))

    let capabilities = try #require(store["UIRequiredDeviceCapabilities"] as? [String])
    #expect(capabilities.contains("arm64"))
    #expect(development["UIRequiredDeviceCapabilities"] == nil)

    // Everything else stays word for word, so the two files cannot
    // quietly drift apart.
    for key in [
      "CFBundleLocalizations",
      "ITSAppUsesNonExemptEncryption",
      "NSAppTransportSecurity",
      "NSCameraUsageDescription",
      "UIApplicationShortcutItems",
      "com.apple.developer.nfc.readersession.iso7816.select-identifiers",
    ] {
      let left = development[key] as? NSObject
      let right = store[key] as? NSObject
      #expect(left == right, "\(key) differs between the two Info.plists")
    }
    let unexplained = Set(development.keys)
      .symmetricDifference(store.keys)
      .subtracting([
        "NSLocalNetworkUsageDescription",
        "NSBonjourServices",
        "UIRequiredDeviceCapabilities",
        "NSBluetoothAlwaysUsageDescription",
        "NSBluetoothPeripheralUsageDescription",
      ])
    #expect(unexplained.isEmpty, "unexplained keys: \(unexplained.sorted())")
  }

  @Test("The macOS store Info.plist and entitlements differ by exactly the gates")
  internal func macStoreShape() throws {
    let development = try Self.plist("Config/ReFineID-Info.plist")
    let store = try Self.plist("Config/ReFineID-Store-Info.plist")

    // What the gate removes: the remote card's network declarations.
    #expect(store["NSLocalNetworkUsageDescription"] == nil)
    #expect(store["NSBonjourServices"] == nil)

    // Everything else stays word for word, so the two files cannot
    // quietly drift apart.
    for key in store.keys {
      let left = development[key] as? NSObject
      let right = store[key] as? NSObject
      #expect(left == right, "\(key) differs between the two Info.plists")
    }
    let unexplained = Set(development.keys)
      .symmetricDifference(store.keys)
      .subtracting([
        "NSLocalNetworkUsageDescription",
        "NSBonjourServices",
        "NSBluetoothAlwaysUsageDescription",
      ])
    #expect(unexplained.isEmpty, "unexplained keys: \(unexplained.sorted())")

    // The entitlements lose exactly the listener: the server side exists
    // only for the remote card's relay, while the client side stays for
    // timestamps and revocation checks.
    let developmentEntitlements = try Self.plist("Config/ReFineID.entitlements")
    let storeEntitlements = try Self.plist("Config/ReFineID-Store.entitlements")
    #expect(storeEntitlements["com.apple.security.network.server"] == nil)
    #expect(storeEntitlements["com.apple.security.network.client"] as? Bool == true)
    for key in storeEntitlements.keys {
      #expect(
        storeEntitlements[key] as? NSObject == developmentEntitlements[key] as? NSObject,
        "\(key) differs between the two entitlements files")
    }
    let unexplainedEntitlements = Set(developmentEntitlements.keys)
      .symmetricDifference(storeEntitlements.keys)
      .subtracting(["com.apple.security.network.server"])
    #expect(
      unexplainedEntitlements.isEmpty,
      "unexplained entitlements: \(unexplainedEntitlements.sorted())")
  }

  @Test("RAPP network declarations are present in shipping containers")
  internal func networkDeclarations() throws {
    for path in [
      "Config/ReFineID-Info.plist",
      "Config/ReFineID-iOS-Info.plist",
      "Config/RappTokenExtension-Info.plist",
    ] {
      let plist = try Self.plist(path)
      #expect(plist["NSLocalNetworkUsageDescription"] is String)
      let services = try #require(plist["NSBonjourServices"] as? [String])
      #expect(services.contains(Self.service))
    }

    let rappIOS = try Self.plist("Config/RappTokenExtension-iOS.entitlements")
    #expect(rappIOS["keychain-access-groups"] is [Any])
    #expect(rappIOS["com.apple.security.smartcard"] == nil)
    #expect(rappIOS["com.apple.security.network.client"] == nil)

    for path in ["Config/ReFineID.entitlements", "Config/RappTokenExtension.entitlements"] {
      let entitlements = try Self.plist(path)
      #expect(entitlements["com.apple.security.network.client"] as? Bool == true)
      #expect(entitlements["com.apple.security.network.server"] as? Bool == true)
    }

    let reader = try Self.plist("Config/TokenExtension.entitlements")
    #expect(reader["com.apple.security.smartcard"] as? Bool == true)
    #expect(reader["com.apple.security.network.client"] == nil)
    #expect(reader["com.apple.security.network.server"] == nil)

    let rapp = try Self.plist("Config/RappTokenExtension.entitlements")
    #expect(rapp["com.apple.security.smartcard"] == nil)
  }

  @Test("Release inspection enforces the separate RAPP archive topology")
  internal func releaseInspectionTopology() throws {
    let source = try String(
      contentsOf: Self.root.appending(
        path: "Scripts/apple-app-store-connect-release-manager.swift"),
      encoding: .utf8)
    #expect(source.contains("ReFineIDRappTokenExtension.appex"))
    #expect(source.contains("fi.refineid.ReFineID.rapp-token"))
    #expect(source.contains("RAPP and direct-reader entitlements are separated"))
    #expect(!source.contains("network entitlements match the gated-relay shape"))
    // Neither candidate carries the remote card: no RAPP extension, no
    // local-network declarations, and on macOS no server entitlement.
    #expect(source.components(separatedBy: "hasRapp: false").count - 1 == 2)
    #expect(source.contains("NSBonjourServices present without the remote card"))
    #expect(source.contains("network.server entitlement present without the remote card"))
    #expect(source.contains("iPhone-only artifact requiring iOS 26.0 and an NFC antenna"))
  }
}
