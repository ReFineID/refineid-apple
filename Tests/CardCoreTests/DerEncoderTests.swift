// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// DER writing rules that signature validity depends on (X.690).
@Suite
internal struct DerEncoderTests {
  @Test
  internal func lengthOctetsUseMinimalForm() {
    // Short form through 127, then one length byte per magnitude byte.
    #expect(
      DerEncoder.octetString(Data(repeating: 0xAA, count: 1))
        == WireHex.data("0401AA")
    )
    #expect(
      DerEncoder.octetString(Data(repeating: 0xAA, count: 127)).prefix(2)
        == WireHex.data("047F")
    )
    #expect(
      DerEncoder.octetString(Data(repeating: 0xAA, count: 128)).prefix(3)
        == WireHex.data("048180")
    )
    #expect(
      DerEncoder.octetString(Data(repeating: 0xAA, count: 256)).prefix(4)
        == WireHex.data("04820100")
    )
  }

  @Test
  internal func integersStripLeadingZerosAndKeepTheirSign() {
    // A leading zero is dropped, a zero octet added when the top bit
    // would otherwise read as negative, and zero is one zero octet.
    #expect(
      DerEncoder.unsignedInteger(WireHex.data("00007F")) == WireHex.data("02017F")
    )
    #expect(
      DerEncoder.unsignedInteger(WireHex.data("80")) == WireHex.data("02020080")
    )
    #expect(
      DerEncoder.unsignedInteger(WireHex.data("0000")) == WireHex.data("020100")
    )
  }

  @Test
  internal func objectIdentifiersEncodeFromDottedNotation() {
    // The first two arcs share an octet; arcs above 127 use base 128
    // with the continuation bit (X.690 §8.19).
    #expect(
      DerEncoder.objectIdentifier("1.2.840.113549.1.7.1")
        == WireHex.data("06092A864886F70D010701")
    )
    #expect(
      DerEncoder.objectIdentifier("2.16.840.1.101.3.4.2.2")
        == WireHex.data("0609608648016503040202")
    )
    #expect(
      DerEncoder.objectIdentifier("1.2.840.10045.4.3.3")
        == WireHex.data("06082A8648CE3D040303")
    )
  }

  @Test
  internal func setOfSortsByEncoding() {
    // DER orders SET OF members by their encodings, not by input
    // order (X.690 §11.6) - a validator that re-sorts would otherwise
    // compute a different digest than the one signed.
    let first = DerEncoder.octetString(WireHex.data("01"))
    let second = DerEncoder.octetString(WireHex.data("02"))
    #expect(DerEncoder.setOf([second, first]) == DerEncoder.setOf([first, second]))
    #expect(DerEncoder.setOf([second, first]) == WireHex.data("3106040101040102"))
  }

  @Test
  internal func retaggingChangesOnlyTheIdentifierOctet() {
    // The signed attributes are signed in their SET form and carried
    // in the implicit form; only the first byte may differ.
    let encoded = DerEncoder.setOf([DerEncoder.octetString(WireHex.data("AB"))])
    let retagged = DerEncoder.retagged(encoded, to: 0xA0)
    #expect(retagged.first == 0xA0)
    #expect(retagged.dropFirst() == encoded.dropFirst())
  }
}
