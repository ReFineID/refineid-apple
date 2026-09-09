// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The document security store's basic incremental-update rules.
@Suite
internal struct PdfValidationStoreTests {
  /// Appending a first store writes every validation-data category.
  @Test
  internal func aFirstStoreCarriesEveryKindOfMaterial() throws {
    let original = StorePdf.document(catalog: StorePdf.catalog())
    let result = try PdfValidationStore.appended(
      to: original,
      material: StorePdf.material(
        certificate: "CERT-A", ocsp: "OCSP-A", crl: "CRL-A"
      )
    )
    let store = try #require(StorePdf.latestStore(in: result))

    #expect(result.prefix(original.count) == original)
    #expect(store.body.contains("/Type /DSS"))
    #expect(StorePdf.references(named: "/Certs", in: store.body).count == 1)
    #expect(StorePdf.references(named: "/OCSPs", in: store.body).count == 1)
    #expect(StorePdf.references(named: "/CRLs", in: store.body).count == 1)
    #expect(StorePdf.text(result).contains("stream\nCERT-A\nendstream"))
    #expect(StorePdf.text(result).contains("stream\nOCSP-A\nendstream"))
    #expect(StorePdf.text(result).contains("stream\nCRL-A\nendstream"))
  }

  /// Empty material adds no meaningless incremental revision.
  @Test
  internal func emptyMaterialLeavesTheDocumentByteIdentical() throws {
    let original = StorePdf.document(catalog: StorePdf.catalog())
    let result = try PdfValidationStore.appended(
      to: original, material: StorePdf.empty
    )
    #expect(result == original)
  }

  /// Duplicate input blobs are emitted only once per category.
  @Test
  internal func duplicateNewMaterialIsWrittenOnce() throws {
    let duplicate = Data("CERT-DUPLICATE".utf8)
    let result = try PdfValidationStore.appended(
      to: StorePdf.document(catalog: StorePdf.catalog()),
      material: PdfValidationStore.Material(
        certificates: [duplicate, duplicate],
        ocspResponses: [],
        revocationLists: []
      )
    )
    let store = try #require(StorePdf.latestStore(in: result))

    #expect(StorePdf.references(named: "/Certs", in: store.body).count == 1)
    #expect(
      StorePdf.occurrences(
        of: "stream\nCERT-DUPLICATE\nendstream", in: result
      ) == 1
    )
  }

  /// A later store retains every reference from the previous store.
  @Test
  internal func aSecondAppendRetainsAllEarlierValidationData() throws {
    let first = try PdfValidationStore.appended(
      to: StorePdf.document(catalog: StorePdf.catalog()),
      material: StorePdf.material(
        certificate: "CERT-OLD", ocsp: "OCSP-OLD", crl: "CRL-OLD"
      )
    )
    let firstStore = try #require(StorePdf.latestStore(in: first))
    let second = try PdfValidationStore.appended(
      to: first,
      material: StorePdf.material(
        certificate: "CERT-NEW", ocsp: "OCSP-NEW", crl: "CRL-NEW"
      )
    )
    let secondStore = try #require(StorePdf.latestStore(in: second))

    for key in ["/Certs", "/OCSPs", "/CRLs"] {
      let oldReferences = StorePdf.references(named: key, in: firstStore.body)
      let newReferences = StorePdf.references(named: key, in: secondStore.body)
      #expect(oldReferences.count == 1)
      #expect(newReferences.count == 2)
      #expect(newReferences.first == oldReferences.first)
    }
    for marker in [
      "CERT-OLD", "OCSP-OLD", "CRL-OLD", "CERT-NEW", "OCSP-NEW", "CRL-NEW",
    ] {
      #expect(StorePdf.text(second).contains(marker))
    }
  }
}
