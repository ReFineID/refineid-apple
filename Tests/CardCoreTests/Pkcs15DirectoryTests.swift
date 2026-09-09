// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct Pkcs15DirectoryTests {
  /// EF.ODF naming EF.5037 for certificates and EF.5034 for keys, each
  /// as a full path from the main file.
  private let objectDirectory = WireHex.data(
    "A00A300804063F0050155034"
      + "A40A300804063F0050155037"
  )

  /// One certificate entry: label, identifier, and the file it lives in.
  private let certificateDirectory = WireHex.data(
    "301E"
      + "30090C0750657275732031"
      + "3003040145"
      + "A10C300A300804063F0050154331"
  )

  /// One private-key entry: label, identifier, usage, and the key
  /// reference the card selects it by.
  private let privateKeyDirectory = WireHex.data(
    "3017"
      + "30090C0750657275732031"
      + "300A040145030200C0020101"
  )

  @Test
  internal func readsDirectoryLocationsFromTheObjectDirectory() {
    let locations = Pkcs15Directory.locations(fromObjectDirectory: objectDirectory)
    #expect(locations.privateKeys == FileIdentifier(value: 0x5034))
    #expect(locations.certificates == FileIdentifier(value: 0x5037))
  }

  @Test
  internal func readsCertificateEntries() throws {
    let certificates = Pkcs15Directory.certificates(fromDirectory: certificateDirectory)
    let entry = try #require(certificates.first)
    #expect(certificates.count == 1)
    #expect(entry.label == "Perus 1")
    #expect(entry.identifier == Data([0x45]))
    #expect(entry.file == FileIdentifier(value: 0x4331))
  }

  @Test
  internal func readsPrivateKeyEntriesWithTheirReference() throws {
    let keys = Pkcs15Directory.privateKeys(fromDirectory: privateKeyDirectory)
    let entry = try #require(keys.first)
    #expect(keys.count == 1)
    #expect(entry.label == "Perus 1")
    #expect(entry.identifier == Data([0x45]))
    #expect(entry.keyReference == 0x01)
  }

  @Test
  internal func pairsCertificatesWithKeysByIdentifier() throws {
    let certificate = try #require(
      Pkcs15Directory.certificates(fromDirectory: certificateDirectory).first)
    let key = try #require(
      Pkcs15Directory.privateKeys(fromDirectory: privateKeyDirectory).first)
    #expect(certificate.identifier == key.identifier)
  }

  @Test
  internal func refusesMalformedDirectories() {
    #expect(Pkcs15Directory.certificates(fromDirectory: Data()).isEmpty)
    #expect(Pkcs15Directory.privateKeys(fromDirectory: Data()).isEmpty)
    let truncated = certificateDirectory.dropLast()
    #expect(Pkcs15Directory.certificates(fromDirectory: Data(truncated)).isEmpty)
    let locations = Pkcs15Directory.locations(fromObjectDirectory: Data([0xA0, 0x01]))
    #expect(locations.certificates == nil)
    #expect(locations.privateKeys == nil)
  }
}
