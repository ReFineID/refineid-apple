// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// A simulated smartcard channel that strictly models ISO 7816-4 security states.
///
/// In ISO 7816-4 / PKCS#15 smartcards:
/// 1. Selecting an application / DF resets the security environment, clearing any previously
///    authenticated PIN state (`isPin1Authenticated = false`).
/// 2. Computing a digital signature (`PSO:CDS`) without first satisfying PIN authentication
///    fails immediately with StatusWord 6982 (`securityNotSatisfied`).
/// 3. Successful PIN1 verification establishes the authenticated state, permitting signature.
internal final class StatefulSmartCardMock: CardChannel, @unchecked Sendable {
  private static let minHeaderByteCount = 4
  private static let offsetClass = 0
  private static let offsetInstruction = 1
  private static let offsetParam1 = 2
  private static let offsetParam2 = 3
  private static let offsetLength = 4
  private static let offsetBody = 5

  private static let claIso7816: UInt8 = 0x00
  private static let insSelect: UInt8 = 0xA4
  private static let insVerify: UInt8 = 0x20
  private static let insMse: UInt8 = 0x22
  private static let insPso: UInt8 = 0x2A

  private static let p1MseSetDst: UInt8 = 0x41
  private static let p2MseSetDst: UInt8 = 0xB6
  private static let p1PsoHash: UInt8 = 0x90
  private static let p2PsoHash: UInt8 = 0xA0
  private static let p1PsoCds: UInt8 = 0x9E
  private static let p2PsoCds: UInt8 = 0x9A

  private static let dummySignatureByte: UInt8 = 0x42
  private static let dummySignatureLength = 64

  private let lock = NSLock()

  internal private(set) var isPin1Authenticated = false
  internal private(set) var selectCount = 0
  internal private(set) var verifyPin1Count = 0
  internal private(set) var computeSignatureCount = 0
  internal private(set) var receivedCommands: [Data] = []

  internal var expectedPin1Digits = "1234"
  internal var dummySignature = Data(
    repeating: dummySignatureByte,
    count: dummySignatureLength
  )

  internal var readChunkLength: ReadChunkLength {
    .plain
  }

  internal init() {
    // In-memory simulation channel.
  }

  internal func transmit(_ payload: Data) -> Data {
    lock.lock()
    defer { lock.unlock() }

    receivedCommands.append(payload)
    guard payload.count >= Self.minHeaderByteCount else {
      return WireHex.data("6700")
    }

    let commandClass = payload[Self.offsetClass]
    let instruction = payload[Self.offsetInstruction]
    let param1 = payload[Self.offsetParam1]
    let param2 = payload[Self.offsetParam2]

    if commandClass == Self.claIso7816, instruction == Self.insSelect {
      selectCount += 1
      isPin1Authenticated = false
      return WireHex.data("9000")
    }
    if commandClass == Self.claIso7816, instruction == Self.insVerify {
      return handleVerify(payload)
    }
    if commandClass == Self.claIso7816,
      instruction == Self.insMse,
      param1 == Self.p1MseSetDst,
      param2 == Self.p2MseSetDst
    {
      return WireHex.data("9000")
    }
    if commandClass == Self.claIso7816, instruction == Self.insPso {
      return handlePso(param1: param1, param2: param2)
    }

    return WireHex.data("9000")
  }

  private func handleVerify(_ payload: Data) -> Data {
    let dataLength =
      payload.count > Self.minHeaderByteCount
      ? Int(payload[Self.offsetLength])
      : 0
    if dataLength == 0 {
      return WireHex.data("63C5")
    }
    let bodyLimit = min(payload.count, Self.offsetBody + dataLength)
    let body = payload.subdata(in: Self.offsetBody..<bodyLimit)
    let pinString = String(bytes: body, encoding: .utf8)?.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let isMatched =
      (pinString?.contains(expectedPin1Digits) == true)
      || (body == Data(expectedPin1Digits.utf8))
    guard isMatched else {
      isPin1Authenticated = false
      return WireHex.data("63C2")
    }
    isPin1Authenticated = true
    verifyPin1Count += 1
    return WireHex.data("9000")
  }

  private func handlePso(param1: UInt8, param2: UInt8) -> Data {
    if param1 == Self.p1PsoHash, param2 == Self.p2PsoHash {
      return WireHex.data("9000")
    }
    if param1 == Self.p1PsoCds, param2 == Self.p2PsoCds {
      guard isPin1Authenticated else {
        return WireHex.data("6982")
      }
      computeSignatureCount += 1
      return dummySignature + WireHex.data("9000")
    }
    return WireHex.data("9000")
  }
}
