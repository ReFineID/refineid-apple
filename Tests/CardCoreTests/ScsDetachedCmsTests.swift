// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The minimal detached SignedData the SCS `cms-pades` form embeds
/// (RFC 5652 section 5).
@Suite
internal struct ScsDetachedCmsTests {
  @Test
  internal func refusesADigestOfTheWrongLength() {
    let outcome = ScsDetachedCms.prepare(
      digest: Data(repeating: 0x11, count: 20),
      certificates: [ScsTestCertificate.make().der],
      hashName: "SHA256"
    )
    guard case .failure(let error) = outcome else {
      Issue.record("expected a refusal")
      return
    }
    #expect(error.code == 400)
    #expect(error.message.contains("32 bytes"))
  }

  @Test
  internal func refusesAnUnknownHashName() {
    let outcome = ScsDetachedCms.prepare(
      digest: Data(repeating: 0x11, count: 20),
      certificates: [ScsTestCertificate.make().der],
      hashName: "UNKNOWN_HASH"
    )
    guard case .failure(let error) = outcome else {
      Issue.record("expected a refusal")
      return
    }
    #expect(error.code == 400)
  }

  @Test
  internal func buildsASignedDataAroundTheSignature() throws {
    let leaf = ScsTestCertificate.make().der
    let digest = Data(repeating: 0x42, count: 32)
    let prepared = ScsDetachedCms.prepare(
      digest: digest,
      certificates: [leaf],
      hashName: "SHA256"
    )
    let cms = try prepared.get()

    // The data the card signs is the DER SET of signed attributes,
    // carrying the message digest verbatim.
    #expect(cms.signedAttributes.first == 0x31)
    #expect(cms.signedAttributes.firstRange(of: digest) != nil)

    let signature = Data(repeating: 0xEE, count: 384)
    let signedData = cms.signedData(signature: signature)
    // ContentInfo: SEQUENCE { id-signedData, [0] SignedData }.
    #expect(signedData.first == 0x30)
    let signedDataOid = DerEncoder.objectIdentifier("1.2.840.113549.1.7.2")
    #expect(signedData.firstRange(of: signedDataOid) != nil)
    // The chain and the signature ride inside.
    #expect(signedData.firstRange(of: leaf) != nil)
    #expect(signedData.firstRange(of: signature) != nil)
    // The signed attributes reappear retagged [0] IMPLICIT: same
    // content, context tag.
    let implicitAttributes =
      Data([0xA0]) + cms.signedAttributes.dropFirst()
    #expect(signedData.firstRange(of: implicitAttributes) != nil)
  }
}
