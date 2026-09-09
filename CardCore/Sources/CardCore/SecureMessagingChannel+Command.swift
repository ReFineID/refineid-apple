// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The command-side plumbing of the secure-messaging envelope: splitting
/// the plain APDU, the Le data object, and the ISO 7816-4 padding both
/// directions share.
extension SecureMessagingChannel {
  /// The pieces of a plain command that secure messaging protects
  /// separately: the header (already carrying the secure-messaging class
  /// bits, because the MAC covers it in that form), the data field, and Le.
  internal struct PlainCommandParts {
    /// The four header bytes, class byte already marked.
    internal let header: Data

    /// The command data field, empty when the command carries none.
    internal let data: Data

    /// The enclosed command's Le, nil when it expects no response data.
    internal let expectedLength: UInt8?

    /// Whether the original instruction byte selects DO'85' rather than
    /// DO'87' for its encrypted command data.
    internal let hasOddInstruction: Bool
  }

  /// Splits a plain short-form command and marks its class byte.
  ///
  /// Extended-length APDUs are refused rather than mis-parsed; nothing in
  /// this driver builds one.
  internal static func commandParts(of plain: Data) throws -> PlainCommandParts {
    let bytes = Array(plain)
    guard bytes.count >= Self.headerLength else { throw Failure.malformedCommand }
    var header = Data(bytes.prefix(Self.headerLength))
    header[header.startIndex] |= PaceValues.classSecureMessagingBit
    let hasOddInstruction = !bytes[Self.instructionByteIndex].isMultiple(
      of: Self.evenInstructionRemainder)
    if bytes.count == Self.headerLength {
      return PlainCommandParts(
        header: header,
        data: Data(),
        expectedLength: nil,
        hasOddInstruction: hasOddInstruction
      )
    }
    if bytes.count == Self.headerLength + 1 {
      return PlainCommandParts(
        header: header,
        data: Data(),
        expectedLength: bytes[Self.headerLength],
        hasOddInstruction: hasOddInstruction
      )
    }
    let dataStart = Self.headerLength + 1
    let dataLength = Int(bytes[Self.headerLength])
    guard dataLength > 0, bytes.count >= dataStart + dataLength else {
      throw Failure.malformedCommand
    }
    let data = Data(bytes[dataStart..<dataStart + dataLength])
    if bytes.count == dataStart + dataLength {
      return PlainCommandParts(
        header: header,
        data: data,
        expectedLength: nil,
        hasOddInstruction: hasOddInstruction
      )
    }
    guard bytes.count == dataStart + dataLength + 1 else {
      throw Failure.malformedCommand
    }
    return PlainCommandParts(
      header: header,
      data: data,
      expectedLength: bytes[dataStart + dataLength],
      hasOddInstruction: hasOddInstruction
    )
  }

  /// ISO 7816-4 padding method 2: append `80`, then `00` to the block
  /// boundary.
  ///
  /// Padding is unconditional, so an already-aligned buffer gains a whole
  /// extra block. That is what makes stripping it unambiguous.
  internal static func padded(_ data: Data) -> Data {
    var buffer = data
    buffer.append(PaceValues.paddingMarkerByte)
    let remainder = buffer.count % AesCbc.blockSize
    if remainder != 0 {
      buffer.append(
        contentsOf: repeatElement(0, count: AesCbc.blockSize - remainder)
      )
    }
    return buffer
  }

  /// Strips ISO 7816-4 padding method 2, returning the input unchanged
  /// when it carries no marker.
  internal static func unpadded(_ data: Data) -> Data {
    let bytes = Array(data)
    var end = bytes.count
    while end > 0, bytes[end - 1] == 0 {
      end -= 1
    }
    guard end > 0, bytes[end - 1] == PaceValues.paddingMarkerByte else {
      return data
    }
    return Data(bytes[0..<(end - 1)])
  }

  /// DO'97' for the enclosed command's Le, or empty when it has none.
  internal func expectedLengthObject(for expectedLength: UInt8?) throws -> Data {
    guard let expectedLength else { return Data() }
    guard
      let object = DerTlvRecord.encoded(
        tag: PaceValues.expectedLengthTag,
        value: Data([expectedLength])
      )
    else {
      throw Failure.oversizedCommand
    }
    return object
  }
}
