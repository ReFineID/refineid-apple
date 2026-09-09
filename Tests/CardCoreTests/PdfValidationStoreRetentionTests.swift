// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Retention and fail-closed behavior for a pre-existing security store.
@Suite
internal struct PdfValidationStoreRetentionTests {
  /// A legal raw PDF string byte that differs from its UTF-8 encoding.
  private static let rawCatalogByte: UInt8 = 0xE9

  /// The UTF-8 bytes that must never replace `rawCatalogByte`.
  private static let transcodedCatalogBytes = Data([0xC3, 0xA9])

  /// Indirect arrays, VRI, and extension entries survive a replacement.
  @Test
  internal func indirectArraysAndUnrecognizedEntriesArePreserved() throws {
    let original = StorePdf.document(
      catalog: StorePdf.catalog(dss: "4 0 R"),
      extraObjects: [
        4: "<< /Type /DSS /Certs 5 0 R /OCSPs [7 0 R] /CRLs [8 0 R]"
          + " /VRI 9 0 R /Future 10 0 R >>",
        5: "[6 0 R]",
        6: StorePdf.stream("CERT-OLD"),
        7: StorePdf.stream("OCSP-OLD"),
        8: StorePdf.stream("CRL-OLD"),
        9: "<< /OLD 6 0 R >>",
        10: "<< /Value (kept) >>",
      ]
    )
    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )
    let store = try #require(StorePdf.latestStore(in: result))

    #expect(StorePdf.references(named: "/Certs", in: store.body).first == "6 0 R")
    #expect(StorePdf.references(named: "/OCSPs", in: store.body) == ["7 0 R"])
    #expect(StorePdf.references(named: "/CRLs", in: store.body) == ["8 0 R"])
    #expect(store.body.contains("/VRI 9 0 R"))
    #expect(store.body.contains("/Future 10 0 R"))
  }

  /// A direct DSS dictionary and direct VRI dictionary are retained too.
  @Test
  internal func directStoreAndVriDictionariesArePreserved() throws {
    let directStore = "<< /Certs [4 0 R] /VRI << /OLD 4 0 R >> >>"
    let original = StorePdf.document(
      catalog: StorePdf.catalog(dss: directStore),
      extraObjects: [4: StorePdf.stream("CERT-OLD")]
    )
    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [],
        ocspResponses: [Data("OCSP-NEW".utf8)],
        revocationLists: []
      )
    )
    let store = try #require(StorePdf.latestStore(in: result))

    #expect(StorePdf.references(named: "/Certs", in: store.body) == ["4 0 R"])
    #expect(StorePdf.references(named: "/OCSPs", in: store.body).count == 1)
    #expect(store.body.contains("/VRI << /OLD 4 0 R >>"))
  }

  /// An unreadable earlier array fails closed instead of losing evidence.
  @Test
  internal func malformedEarlierStoreIsRefused() {
    let original = StorePdf.document(
      catalog: StorePdf.catalog(dss: "4 0 R"),
      extraObjects: [
        4: "<< /Certs [5 0 R false] >>",
        5: StorePdf.stream("CERT-OLD"),
      ]
    )
    #expect(throws: PdfSigningError.structureUnreadable) {
      _ = try PdfValidationStore.appended(
        to: original,
        material: PdfValidationStore.Material(
          certificates: [Data("CERT-NEW".utf8)],
          ocspResponses: [],
          revocationLists: []
        )
      )
    }
  }

  /// DSS-looking text inside other values is not a catalog DSS entry.
  @Test
  internal func nestedOrQuotedDssNamesAreNotReplaced() throws {
    let catalog = StorePdf.catalog(
      additions: "/Note (text /DSS 99 0 R) /Metadata << /DSS 98 0 R >>"
    )
    let result = try PdfValidationStore.appended(
      to: StorePdf.document(catalog: catalog),
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )
    let latestCatalog = try #require(StorePdf.latestObject(1, in: result))
    let store = try #require(StorePdf.latestStore(in: result))

    #expect(latestCatalog.contains("/Note (text /DSS 99 0 R)"))
    #expect(latestCatalog.contains("/Metadata << /DSS 98 0 R >>"))
    #expect(latestCatalog.contains("/DSS \(store.number) 0 R"))
  }

  /// An escaped spelling of the DSS name is recognized as the same key.
  @Test
  internal func escapedDssNameIsUpdatedWithoutAddingADuplicate() throws {
    let original = StorePdf.document(
      catalog: "<< /Type /Catalog /Pages 2 0 R /D#53S 4 0 R >>",
      extraObjects: [
        4: "<< /Certs [5 0 R] >>",
        5: StorePdf.stream("CERT-OLD"),
      ]
    )
    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )
    let latestCatalog = try #require(StorePdf.latestObject(1, in: result))
    let newNumber = try #require(
      StorePdf.reference(named: "/D#53S", in: latestCatalog)
    )
    let store = try #require(StorePdf.latestObject(newNumber, in: result))

    #expect(!latestCatalog.contains("/DSS"))
    #expect(StorePdf.references(named: "/Certs", in: store).first == "5 0 R")
    #expect(StorePdf.references(named: "/Certs", in: store).count == 2)
  }

  /// Rewriting the catalog preserves legal raw eight-bit PDF string bytes.
  @Test
  internal func rawCatalogBytesAreNotTranscodedToUtf8() throws {
    let marker = Data("(raw-X-byte)".utf8)
    var original = StorePdf.document(
      catalog: StorePdf.catalog(additions: "/Note (raw-X-byte)")
    )
    let markerRange = try #require(original.range(of: marker))
    let byteIndex = markerRange.lowerBound + Data("(raw-".utf8).count
    original[byteIndex] = Self.rawCatalogByte

    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )

    let rawByteCount = result.reduce(into: 0) { count, byte in
      if byte == Self.rawCatalogByte { count += 1 }
    }
    #expect(rawByteCount == 2)
    #expect(!result.contains(Self.transcodedCatalogBytes))
  }

  /// Unknown prior DSS values retain their raw bytes in the replacement.
  @Test
  internal func rawPreviousStoreBytesAreNotTranscodedToUtf8() throws {
    let marker = Data("(store-X-byte)".utf8)
    var original = StorePdf.document(
      catalog: StorePdf.catalog(dss: "4 0 R"),
      extraObjects: [4: "<< /Future (store-X-byte) >>"]
    )
    let markerRange = try #require(original.range(of: marker))
    let byteIndex = markerRange.lowerBound + Data("(store-".utf8).count
    original[byteIndex] = Self.rawCatalogByte

    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )

    let rawByteCount = result.reduce(into: 0) { count, byte in
      if byte == Self.rawCatalogByte { count += 1 }
    }
    #expect(rawByteCount == 2)
    #expect(!result.contains(Self.transcodedCatalogBytes))
  }

  /// The carried trailer identifier is binary PDF syntax, not UTF-8 text.
  @Test
  internal func rawTrailerIdentifierIsNotTranscodedToUtf8() throws {
    let trailerPrefix = Data("trailer\n<< /Size 4 /Root 1 0 R".utf8)
    let identifier = Data(" /ID [(id-X-byte)(second)]".utf8)
    var original = StorePdf.document(catalog: StorePdf.catalog())
    let trailerRange = try #require(original.range(of: trailerPrefix))
    original.insert(contentsOf: identifier, at: trailerRange.upperBound)
    let marker = Data("(id-X-byte)".utf8)
    let markerRange = try #require(original.range(of: marker))
    let byteIndex = markerRange.lowerBound + Data("(id-".utf8).count
    original[byteIndex] = Self.rawCatalogByte

    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )

    let rawByteCount = result.reduce(into: 0) { count, byte in
      if byte == Self.rawCatalogByte { count += 1 }
    }
    #expect(rawByteCount == 2)
    #expect(!result.contains(Self.transcodedCatalogBytes))
  }

  /// A closing bracket inside an ID string is data, not the array boundary.
  @Test
  internal func trailerIdentifierUsesTokenAwareArrayBoundary() throws {
    let trailerPrefix = Data("trailer\n<< /Size 4 /Root 1 0 R".utf8)
    let identifierText = " /ID [(first]value)(second)]"
    var original = StorePdf.document(catalog: StorePdf.catalog())
    let trailerRange = try #require(original.range(of: trailerPrefix))
    original.insert(
      contentsOf: Data(identifierText.utf8),
      at: trailerRange.upperBound
    )

    let result = try PdfValidationStore.appended(
      to: original,
      material: PdfValidationStore.Material(
        certificates: [Data("CERT-NEW".utf8)],
        ocspResponses: [],
        revocationLists: []
      )
    )

    #expect(
      StorePdf.occurrences(of: "/ID [(first]value)(second)]", in: result)
        == 2
    )
  }
}
