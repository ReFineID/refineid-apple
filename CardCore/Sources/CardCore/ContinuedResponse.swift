// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A card response joined across its `61xx` GET RESPONSE continuations,
/// without the short-form payload cap.
///
/// `ResponseApdu` refuses anything beyond 256 payload bytes, which is the
/// right gate for a plain command but too tight one layer lower: the outer
/// leg of a secure-messaging exchange carries the DO'87' cryptogram (the
/// plaintext rounded up to a whole block, plus a padding indicator), DO'99'
/// and DO'8E' on top of a payload that may already be a full chunk, so the
/// outer response routinely exceeds what `ResponseApdu` accepts even when
/// the inner one does not.
///
/// This type is that lower layer, shared by PACE (which runs before any
/// secure messaging exists) and by `SecureMessagingChannel` (which must see
/// the whole outer response before it can verify anything). It joins
/// continuations, classifies the final status word, and interprets nothing
/// else.
internal struct ContinuedResponse {
  /// Upper bound on GET RESPONSE continuations for one command; a card
  /// announcing more than this is misbehaving.
  private static let maximumContinuations: Int = 128

  /// The joined response body, without the status word.
  internal let payload: Data

  /// The classified status word of the final response.
  internal let statusWord: StatusWord

  /// The response back in wire form: payload followed by the two status
  /// bytes, which is what a `CardChannel` hands its caller.
  internal var encoded: Data {
    var bytes = payload
    let value = statusWord.encoded
    bytes.append(UInt8(truncatingIfNeeded: value >> Iso7816Values.byteShift))
    bytes.append(UInt8(truncatingIfNeeded: value))
    return bytes
  }

  /// Holds an already-parsed response; parsing happens in `single`.
  private init(payload: Data, statusWord: StatusWord) {
    self.payload = payload
    self.statusWord = statusWord
  }

  /// Transmits one command and follows every `61xx` continuation.
  ///
  /// Bounded in both rounds and total size, so a card that keeps
  /// announcing more data cannot hold the session open indefinitely.
  internal static func transmitting(
    _ command: Data,
    over channel: any CardChannel
  ) throws -> Self {
    var current = try Self.single(command, over: channel)
    var joined = current.payload
    var rounds = 0
    while case .responseAvailable(let count) = current.statusWord {
      rounds += 1
      guard
        rounds <= Self.maximumContinuations,
        joined.count <= BinaryReadAssembler.maximumTotalLength
      else {
        throw CardOperationError.malformedResponse
      }
      current = try Self.single(
        CommandApdu.getResponse(announcedCount: count).encoded,
        over: channel
      )
      joined.append(current.payload)
    }
    return Self(payload: joined, statusWord: current.statusWord)
  }

  /// One transmit, parsed into payload and status word with no size cap.
  private static func single(
    _ command: Data,
    over channel: any CardChannel
  ) throws -> Self {
    let bytes = Array(try channel.transmit(command))
    guard bytes.count >= ResponseApdu.statusWordLength else {
      throw CardOperationError.malformedResponse
    }
    let payloadLength = bytes.count - ResponseApdu.statusWordLength
    return Self(
      payload: Data(bytes.prefix(payloadLength)),
      statusWord: StatusWord(
        sw1: bytes[payloadLength],
        sw2: bytes[payloadLength + 1]
      )
    )
  }
}
