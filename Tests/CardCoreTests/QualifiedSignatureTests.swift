// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// The qualified-signature chain at the operations level.
///
/// VERIFY PIN2 immediately before MSE:SET naming the qualified key,
/// then PSO:HASH and PSO:CDS with the exact expected length. Vectors
/// follow FINEID S1 v4.2 §3.5-3.8.
@Suite
internal struct QualifiedSignatureTests {
  @Test
  internal func qualifiedChainVerifiesPin2ThenSigns() throws {
    let digest = String(repeating: "AB", count: 48)
    let signature = String(repeating: "CD", count: 96)
    let channel = ScriptedChannel([
      ("0020001100", "63C5"),
      ("002000820C363534333231000000000000", "9000"),
      ("002241B606800154840102", "9000"),
      ("002A90A0329030" + digest, "9000"),
      ("002A9E9A60", signature + "9000"),
    ])
    let operations = CardOperations(channel: channel)
    guard let pin = Pin2(digits: "654321") else {
      Issue.record("valid PIN failed to construct")
      return
    }
    try operations.verifyPin2(pin.consumeForSingleTransmission())
    let exactLength = try #require(ExpectedResponseLength(count: 96))
    let raw = try operations.computeQualifiedSignature(
      overDigest: WireHex.data(digest),
      algorithm: SigningAlgorithm(hash: .sha384, scheme: .ecdsa),
      expectedSignatureLength: exactLength
    )
    #expect(raw == WireHex.data(signature))
    #expect(channel.isExhausted)
  }

  @Test
  internal func qualifiedChainRefusesWithoutTheKey() {
    // A card that refuses MSE:SET for the qualified key (for example a
    // profile without the slot) surfaces the refusal as signRejected
    // before any PSO command is sent.
    let channel = ScriptedChannel([
      ("002241B606800154840102", "6A88")
    ])
    let operations = CardOperations(channel: channel)
    do {
      _ = try operations.computeQualifiedSignature(
        overDigest: WireHex.data(String(repeating: "AB", count: 48)),
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .ecdsa),
        expectedSignatureLength: ExpectedResponseLength(count: 96)
      )
      Issue.record("expected signRejected")
    } catch let error as CardOperationError {
      #expect(error == .signRejected(.referenceDataNotFound))
    } catch {
      Issue.record("unexpected error type")
    }
    #expect(channel.isExhausted)
  }

  @Test
  internal func rsa2048QualifiedSignatureUsesTheFullShortResponse() throws {
    let digest = String(repeating: "AB", count: 48)
    let signature = String(repeating: "11", count: 256)
    let channel = ScriptedChannel([
      ("002241B606800152840102", "9000"),
      ("002A90A0329030" + digest, "9000"),
      ("002A9E9A00", signature + "9000"),
    ])
    let exactLength = try #require(ExpectedResponseLength(count: 256))

    let raw = try CardOperations(channel: channel)
      .computeQualifiedSignature(
        overDigest: WireHex.data(digest),
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        expectedSignatureLength: exactLength
      )

    #expect(raw == WireHex.data(signature))
    #expect(raw.count == 256)
    #expect(channel.isExhausted)
  }

  @Test
  internal func rsa3072QualifiedSignatureJoinsTheFullContinuation() throws {
    let digest = String(repeating: "AB", count: 48)
    let firstSignaturePart = String(repeating: "11", count: 256)
    let secondSignaturePart = String(repeating: "22", count: 128)
    let channel = ScriptedChannel([
      ("002241B606800152840102", "9000"),
      ("002A90A0329030" + digest, "9000"),
      ("002A9E9A00", firstSignaturePart + "6180"),
      ("00C0000080", secondSignaturePart + "9000"),
    ])

    let signature = try CardOperations(channel: channel)
      .computeQualifiedSignature(
        overDigest: WireHex.data(digest),
        algorithm: SigningAlgorithm(hash: .sha384, scheme: .rsaPkcs1),
        expectedSignatureLength: nil
      )

    #expect(signature == WireHex.data(firstSignaturePart + secondSignaturePart))
    #expect(signature.count == 384)
    #expect(channel.isExhausted)
  }
}
