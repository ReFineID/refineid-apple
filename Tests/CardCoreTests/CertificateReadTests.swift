// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

@Suite
internal struct CertificateReadTests {
  @Test
  internal func authenticationLeafReadsUnderTheApplication() throws {
    // Auth leaf lives under the PKCS#15 application: select app, select
    // EF.4331, read to a short chunk. A tiny synthetic DER stands in.
    let der = String(repeating: "AB", count: 12)
    let channel = ScriptedChannel([
      ("00A4040C0CA000000063504B43532D3135", "9000"),
      ("00A4020C024331", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.authentication)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func issuingCertificateReadsUnderTheMainFile() throws {
    // Issuer chain lives under MF: select MF, select EF.4336, read.
    let der = String(repeating: "CD", count: 8)
    let channel = ScriptedChannel([
      ("00A4000C023F00", "9000"),
      ("00A4020C024336", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.issuing)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func mainFileSelectFallsBackToSelectByName() throws {
    // First MF variant (P1=00) is refused; the by-name variant (P1=04)
    // is tried and succeeds.
    let der = "EEFF"
    let channel = ScriptedChannel([
      ("00A4000C023F00", "6A82"),
      ("00A4040C023F00", "9000"),
      ("00A4020C024334", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.root)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func elementaryFileSelectFallsBackToSelectByFileId() throws {
    // Under the app, the EF-under-DF variant (P1=02) is refused; the
    // by-file-id variant (P1=00) succeeds.
    let der = "1234"
    let channel = ScriptedChannel([
      ("00A4040C0CA000000063504B43532D3135", "9000"),
      ("00A4020C024331", "6A82"),
      ("00A4000C024331", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.authentication)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func absentSlotSurfacesAsSelectRejected() {
    // Both documented homes of the issuing CA - citizen EF.4336, then
    // organization EF.4333 (S4-2 v4.0 §4.6.6) - are tried before the
    // slot reports itself unprovisioned.
    let channel = ScriptedChannel([
      ("00A4000C023F00", "9000"),
      ("00A4020C024336", "6A82"),
      ("00A4000C024336", "6A82"),
      ("00A4000C023F00", "9000"),
      ("00A4020C024333", "6A82"),
      ("00A4000C024333", "6A82"),
    ])
    #expect(throws: CardOperationError.selectRejected(.fileNotFound)) {
      _ = try CardOperations(channel: channel).readCertificate(.issuing)
    }
  }

  @Test
  internal func organizationIssuingCertificateReadsFromEf4333() throws {
    // The organization card keeps its issuing CA in EF.4333 under the
    // main file (S4-2 v4.0 §4.6.6): the citizen home EF.4336 is
    // refused, the organization home answers.
    let der = String(repeating: "4A", count: 8)
    let channel = ScriptedChannel([
      ("00A4000C023F00", "9000"),
      ("00A4020C024336", "6A82"),
      ("00A4000C024336", "6A82"),
      ("00A4000C023F00", "9000"),
      ("00A4020C024333", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.issuing)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func organizationSignatureLeafReadsUnderEsign() throws {
    // The organization card keeps the signature leaf under DF.ESIGN
    // (S4-2 v4.0 §4.6.22). Under the application the EF select is
    // refused honestly, but the select-by-identifier form answers
    // success for the absent file and the read then refuses with no
    // current file - the location loop must treat that as "not
    // here" and carry on to MF -> DF.ESIGN by name -> EF.4332.
    let der = String(repeating: "5B", count: 10)
    let channel = ScriptedChannel([
      ("00A4040C0CA000000063504B43532D3135", "9000"),
      ("00A4020C024332", "6A82"),
      ("00A4000C024332", "9000"),
      ("00B0000080", "6986"),
      ("00A4000C023F00", "9000"),
      ("00A4040C06452E5349474E", "9000"),
      ("00A4020C024332", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.qualifiedSignature)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func esignDirectorySelectFallsBackToFileIdentifier() throws {
    // DF.ESIGN by its S4-2 v4.0 §4.6.21 name comes first - the
    // file-identifier variant can answer success without making the
    // directory current - and the identifier stays as the fallback
    // for a card that refuses selection by name.
    let der = "6C6D"
    let channel = ScriptedChannel([
      ("00A4040C0CA000000063504B43532D3135", "9000"),
      ("00A4020C024332", "6A82"),
      ("00A4000C024332", "6A82"),
      ("00A4000C023F00", "9000"),
      ("00A4040C06452E5349474E", "6A82"),
      ("00A4000C025016", "9000"),
      ("00A4020C024332", "9000"),
      ("00B0000080", der + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.qualifiedSignature)
    #expect(read == WireHex.data(der))
    #expect(channel.isExhausted)
  }

  @Test
  internal func multiChunkCertificateAssemblesInOrder() throws {
    let first = String(repeating: "A1", count: 128)
    let second = String(repeating: "B2", count: 40)
    let channel = ScriptedChannel([
      ("00A4040C0CA000000063504B43532D3135", "9000"),
      ("00A4020C024331", "9000"),
      ("00B0000080", first + "9000"),
      ("00B0008080", second + "9000"),
    ])
    let read = try CardOperations(channel: channel)
      .readCertificate(.authentication)
    #expect(read == WireHex.data(first + second))
    #expect(channel.isExhausted)
  }
}
