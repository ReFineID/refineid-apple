// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// How many bytes one READ BINARY of a chunked read may ask for, chosen
/// by the transport that has to carry the answer home.
///
/// `BinaryReadAssembler` ends a read-to-end-of-file when a chunk comes
/// back SHORTER than it asked for. That inference is sound only while
/// the transport can carry a whole chunk in a single response, so the
/// chunk length is a property of the transport rather than a free
/// number. Over secure messaging the answer travels as DO'87' (the
/// plaintext padded up to a whole cipher block, behind a tag, its
/// length octets and a padding indicator), then DO'99' and DO'8E'. A
/// chunk whose protected form overran one short-form response would
/// come back short on EVERY read, and the assembler would read that as
/// end of file and hand back a truncated certificate -- silently, as
/// wrong data rather than as an error.
///
/// The two cases are the two kinds of transport the driver has, and
/// there is deliberately no way to make a third: an arbitrary length is
/// exactly the mistake this type exists to prevent.
public enum ReadChunkLength: Equatable, Sendable {
  /// The chunk for a transport that carries plain responses: the FINEID
  /// published guideline value, and what every contact read has always
  /// asked for.
  case plain

  /// The chunk for a secure-messaged transport: the plain chunk, capped
  /// to what one protected response can carry whole.
  case secureMessaged

  /// The FINEID published guideline chunk for READ BINARY.
  private static let plainCount: Int = 128

  /// What DO'87' costs around the ciphertext: the tag byte, two
  /// long-form length octets (a cryptogram this size always exceeds the
  /// 127-byte short form), and the padding-content indicator.
  private static let cryptogramObjectOverhead: Int = 4

  /// What DO'99' costs: the tag byte, its length octet, and the two
  /// status bytes it carries.
  private static let statusObjectLength: Int = 4

  /// What DO'8E' costs: the tag byte, its length octet, and the
  /// eight-byte truncated checksum.
  private static let macObjectLength: Int = 10

  /// ISO 7816-4 padding method 2 is unconditional, so the plaintext has
  /// to leave room for at least the `80` marker byte: a plaintext that
  /// exactly filled the last block would gain a whole extra one.
  private static let paddingMarkerLength: Int = 1

  /// The largest plaintext whose protected response still fits one
  /// short-form response.
  ///
  /// The budget is `ExpectedResponseLength.maximum` less the three data
  /// objects' overhead; what remains is rounded DOWN to whole cipher
  /// blocks, and one byte of the last block belongs to the padding
  /// marker. On today's values that is 223 bytes, comfortably above the
  /// plain chunk -- which is the point: the cap is a ceiling the chunk
  /// must stay under, not a target to grow to.
  private static var secureMessagingCeiling: Int {
    let objectOverhead =
      Self.cryptogramObjectOverhead + Self.statusObjectLength + Self.macObjectLength
    let ciphertextBudget = ExpectedResponseLength.maximum - objectOverhead
    let wholeBlocks = ciphertextBudget / AesCbc.blockSize
    return wholeBlocks * AesCbc.blockSize - Self.paddingMarkerLength
  }

  /// The number of bytes to ask the card for.
  public var count: Int {
    switch self {
    case .plain:
      Self.plainCount

    case .secureMessaged:
      min(Self.plainCount, Self.secureMessagingCeiling)
    }
  }
}
