// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import PKCS11Bridge
import Testing

@Suite
internal struct EcEncodingTests {
  private let widthTwo = 2

  @Test
  internal func parametersMatchKnownWidthsOnly() {
    #expect(EcEncoding.parameters(fieldWidth: Int(EcFieldBytesP256)) != nil)
    #expect(EcEncoding.parameters(fieldWidth: Int(EcFieldBytesP384)) != nil)
    #expect(EcEncoding.parameters(fieldWidth: Int(EcFieldBytesP521)) != nil)
    #expect(EcEncoding.parameters(fieldWidth: Int(EcFieldBytesP256) - 1) == nil)
  }

  @Test
  internal func fieldWidthReadsUncompressedPoints() {
    let coordinateBytes = Int(EcFieldBytesP256) * 2
    let point = Data([EcUncompressedPointTag]) + Data(count: coordinateBytes)
    #expect(EcEncoding.fieldWidth(uncompressedPoint: point) == Int(EcFieldBytesP256))
    let truncated = point.dropLast()
    #expect(EcEncoding.fieldWidth(uncompressedPoint: Data(truncated)) == nil)
    let wrongTag = Data([Asn1IntegerTag]) + Data(count: coordinateBytes)
    #expect(EcEncoding.fieldWidth(uncompressedPoint: wrongTag) == nil)
  }

  @Test
  internal func wrapsPointsInOctetStrings() {
    let shortPoint = Data([EcUncompressedPointTag, 1, 2])
    let wrapped = EcEncoding.wrappedPoint(shortPoint)
    #expect(wrapped == Data([Asn1OctetStringTag, 3]) + shortPoint)

    let longThreshold = Int(Asn1LongFormLengthFlag)
    let longPoint = Data(count: longThreshold)
    let longWrapped = EcEncoding.wrappedPoint(longPoint)
    let longHeader = Data([
      Asn1OctetStringTag, Asn1LongFormLengthFlag | 1, CK_BYTE(longThreshold),
    ])
    #expect(longWrapped == longHeader + longPoint)
  }

  @Test
  internal func convertsDerSignaturesToRaw() {
    // SEQUENCE { INTEGER 1, INTEGER 2 } -> r=1, s=2, each padded.
    let simple = Data([Asn1SequenceTag, 6, Asn1IntegerTag, 1, 1, Asn1IntegerTag, 1, 2])
    #expect(
      EcEncoding.rawSignature(fromDer: simple, fieldWidth: widthTwo)
        == Data([0, 1, 0, 2]))

    // High-bit integers carry a leading zero in DER that raw form drops.
    let highBit: CK_BYTE = 128
    let padded = Data([
      Asn1SequenceTag, 8,
      Asn1IntegerTag, 2, 0, highBit,
      Asn1IntegerTag, 2, 0, highBit + 1,
    ])
    #expect(
      EcEncoding.rawSignature(fromDer: padded, fieldWidth: widthTwo)
        == Data([0, highBit, 0, highBit + 1]))
  }

  @Test
  internal func rejectsMalformedDerSignatures() {
    let notASequence = Data([Asn1IntegerTag, 1, 1])
    #expect(EcEncoding.rawSignature(fromDer: notASequence, fieldWidth: widthTwo) == nil)

    let truncated = Data([Asn1SequenceTag, 6, Asn1IntegerTag, 1, 1])
    #expect(EcEncoding.rawSignature(fromDer: truncated, fieldWidth: widthTwo) == nil)

    // r wider than the field must be refused, not silently truncated.
    let oversized = Data([
      Asn1SequenceTag, 7, Asn1IntegerTag, 3, 1, 2, 3, Asn1IntegerTag, 1, 2,
    ])
    #expect(EcEncoding.rawSignature(fromDer: oversized, fieldWidth: widthTwo) == nil)
  }
}
