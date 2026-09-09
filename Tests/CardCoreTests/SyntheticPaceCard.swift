// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import CryptoKit
import Foundation

/// A synthetic card that plays the card half of PACE with the same
/// mathematics, independently implemented.
///
/// This is what makes an offline PACE test meaningful. The card picks its
/// own nonce and its own two ephemeral scalars, derives the mapped
/// generator, the shared secret and the session keys by its own code path,
/// and computes the authentication tokens with its own key derivation
/// function written out here rather than taken from the module under test.
/// If the terminal and this card arrive at the same Kenc and Kmac, then
/// every step in between -- the nonce decryption, the generic mapping, the
/// key agreement on the mapped generator, and both token encodings -- agreed
/// as well. No hardware is involved.
internal final class SyntheticPaceCard: CardChannel {
  /// Thrown when the terminal's command is not what the current round
  /// expects.
  internal struct Rejected: Error, Equatable {}

  /// SELECT, which the terminal issues to reach main file before PACE.
  ///
  /// A real card refuses MSE:Set AT anywhere else, so the terminal always
  /// sends this first and this card has to answer it.
  private static let select: UInt8 = 0xA4

  /// MANAGE SECURITY ENVIRONMENT.
  private static let manageSecurityEnvironment: UInt8 = 0x22

  /// GENERAL AUTHENTICATE.
  private static let generalAuthenticate: UInt8 = 0x86

  /// Tag `7C`, dynamic authentication data.
  private static let dynamicAuthenticationDataTag: UInt8 = 0x7C

  /// Tag `80` inside `7C`: the encrypted nonce.
  private static let encryptedNonceTag: UInt8 = 0x80

  /// Tag `81` inside `7C`: the terminal's mapping data.
  private static let mappingDataTerminalTag: UInt8 = 0x81

  /// Tag `82` inside `7C`: the card's mapping data.
  private static let mappingDataCardTag: UInt8 = 0x82

  /// Tag `83` inside `7C`: the terminal's ephemeral public key.
  private static let ephemeralPublicKeyTerminalTag: UInt8 = 0x83

  /// Tag `84` inside `7C`: the card's ephemeral public key.
  private static let ephemeralPublicKeyCardTag: UInt8 = 0x84

  /// Tag `85` inside `7C`: the terminal's authentication token.
  private static let authenticationTokenTerminalTag: UInt8 = 0x85

  /// Tag `86` inside `7C`: the card's authentication token.
  private static let authenticationTokenCardTag: UInt8 = 0x86

  /// Tag `06`, OBJECT IDENTIFIER.
  private static let objectIdentifierTag: UInt8 = 0x06

  /// The first byte of tag `7F49`.
  private static let publicKeyTemplateFirstByte: UInt8 = 0x7F

  /// The second byte of tag `7F49`.
  private static let publicKeyTemplateSecondByte: UInt8 = 0x49

  /// Tag `86` inside `7F49`: the point the token covers.
  private static let publicKeyTemplatePointTag: UInt8 = 0x86

  /// `id-PACE-ECDH-GM-AES-CBC-CMAC-256` under the BSI branch
  /// `0.4.0.127.0.7.2.2.4.2.4`, transcribed here independently of the
  /// module's own copy.
  private static let protocolOidHex = "04007F00070202040204"

  /// Normal processing.
  private static let successHex = "9000"

  /// Where a short-form command's Lc byte sits.
  private static let lengthOffset: Int = 4

  /// Where a short-form command's body starts.
  private static let bodyOffset: Int = 5

  /// The Doc 9303 key derivation counter for Kenc.
  private static let encryptionCounter: UInt32 = 1

  /// The Doc 9303 key derivation counter for Kmac.
  private static let macCounter: UInt32 = 2

  /// The Doc 9303 key derivation counter for the password key.
  private static let passwordCounter: UInt32 = 3

  /// The key that encrypts the nonce, derived from the CAN digits.
  private let passwordKey: Data

  /// The card's PACE nonce.
  private let nonce: Data

  /// The card's ephemeral scalar for the generic mapping.
  private let mappingScalar: U384

  /// The card's ephemeral scalar for the key agreement.
  private let agreementScalar: U384

  /// The mapped generator, once the mapping round has run.
  private var mappedGenerator: BrainpoolPoint?

  /// The card's ephemeral public key on the mapped generator.
  private var cardPublicKey: BrainpoolPoint?

  /// The terminal's ephemeral public key on the mapped generator.
  private var terminalPublicKey: BrainpoolPoint?

  /// The card's own copy of Kmac.
  ///
  /// Kept here because `PaceSessionKeys` deliberately hands out no key
  /// bytes; the card keeps what it derived rather than reading it back.
  private var macKeyMaterial: Data?

  /// The session keys the card derived, available after a completed run.
  internal private(set) var sessionKeys: PaceSessionKeys?

  /// PACE runs before any secure messaging exists, so this card is a
  /// plain transport; nothing reads a file over it.
  internal var readChunkLength: ReadChunkLength {
    .plain
  }

  internal init(
    accessNumberDigits: String,
    nonce: Data,
    mappingScalar: U384,
    agreementScalar: U384
  ) {
    self.passwordKey = Self.derivedKey(
      from: Data(accessNumberDigits.utf8),
      counter: Self.passwordCounter
    )
    self.nonce = nonce
    self.mappingScalar = mappingScalar
    self.agreementScalar = agreementScalar
  }

  /// The ICAO Doc 9303 part 11 section 9.7.1.2 AES-256 key derivation,
  /// written out here so the test does not borrow the module's version.
  private static func derivedKey(from secret: Data, counter: UInt32) -> Data {
    var input = secret
    withUnsafeBytes(of: counter.bigEndian) { input.append(contentsOf: $0) }
    return Data(SHA256.hash(data: input))
  }

  /// One data object, refusing anything the encoder cannot represent.
  private static func object(tag: UInt8, value: Data) throws -> Data {
    guard let encoded = DerTlvRecord.encoded(tag: tag, value: value) else {
      throw Rejected()
    }
    return encoded
  }

  /// A `7C` template carrying one context data object, with the success
  /// status word appended.
  private static func response(contextTag: UInt8, value: Data) throws -> Data {
    let template = try Self.object(
      tag: Self.dynamicAuthenticationDataTag,
      value: try Self.object(tag: contextTag, value: value)
    )
    return template + WireHex.data(Self.successHex)
  }

  /// The SEC1 encoding of a point the protocol requires to be finite.
  private static func encodedPoint(_ point: BrainpoolPoint) throws -> Data {
    guard let encoded = point.encodeUncompressed() else { throw Rejected() }
    return encoded
  }

  /// The authentication token input `7F49 { 06 OID, 86 point }`.
  private static func tokenInput(for point: BrainpoolPoint) throws -> Data {
    let body =
      try Self.object(
        tag: Self.objectIdentifierTag,
        value: WireHex.data(Self.protocolOidHex)
      )
      + Self.object(
        tag: Self.publicKeyTemplatePointTag,
        value: try Self.encodedPoint(point)
      )
    let template = try Self.object(
      tag: Self.publicKeyTemplateSecondByte,
      value: body
    )
    return Data([Self.publicKeyTemplateFirstByte]) + template
  }

  /// Answers one command APDU.
  internal func transmit(_ payload: Data) throws -> Data {
    let bytes = Array(payload)
    guard bytes.count >= Self.bodyOffset else { throw Rejected() }
    if bytes[1] == Self.select || bytes[1] == Self.manageSecurityEnvironment {
      return WireHex.data(Self.successHex)
    }
    guard bytes[1] == Self.generalAuthenticate else { throw Rejected() }
    let dataLength = Int(bytes[Self.lengthOffset])
    guard bytes.count >= Self.bodyOffset + dataLength else { throw Rejected() }
    return try round(
      Data(bytes[Self.bodyOffset..<(Self.bodyOffset + dataLength)])
    )
  }

  /// Dispatches one GENERAL AUTHENTICATE by the context tag it carries.
  private func round(_ data: Data) throws -> Data {
    let outer = try DerTlvRecord.sequence(in: data)
    guard
      let template = outer.first,
      template.tag == Self.dynamicAuthenticationDataTag
    else {
      throw Rejected()
    }
    let inner = try DerTlvRecord.sequence(in: template.value)
    guard let object = inner.first else { return try encryptedNonce() }
    switch object.tag {
    case Self.mappingDataTerminalTag:
      return try mapGenerator(terminalMappingData: object.value)

    case Self.ephemeralPublicKeyTerminalTag:
      return try agree(terminalPublicKeyData: object.value)

    case Self.authenticationTokenTerminalTag:
      return try authenticate(terminalToken: object.value)

    default:
      throw Rejected()
    }
  }

  /// Round one: the nonce under the key the CAN derives.
  private func encryptedNonce() throws -> Data {
    let ciphertext = try AesCbc.encrypt(
      key: passwordKey,
      initializationVector: Data(repeating: 0, count: AesCbc.blockSize),
      plaintext: nonce
    )
    return try Self.response(contextTag: Self.encryptedNonceTag, value: ciphertext)
  }

  /// Round two: the generic mapping, `G' = s*G + H`.
  private func mapGenerator(terminalMappingData: Data) throws -> Data {
    guard
      let terminalPoint = BrainpoolPoint.decodeUncompressed(terminalMappingData),
      let nonceScalar = U384(bigEndianBytes: nonce)
    else {
      throw Rejected()
    }
    let shared = BrainpoolP384r1.multiply(terminalPoint, by: mappingScalar)
    mappedGenerator = BrainpoolP384r1.multiplyGenerator(by: nonceScalar).adding(shared)
    return try Self.response(
      contextTag: Self.mappingDataCardTag,
      value: try Self.encodedPoint(BrainpoolP384r1.multiplyGenerator(by: mappingScalar))
    )
  }

  /// Round three: the key agreement on the mapped generator, and the key
  /// derivation from the agreed point's x-coordinate.
  private func agree(terminalPublicKeyData: Data) throws -> Data {
    guard
      let mappedGenerator,
      let terminalPoint = BrainpoolPoint.decodeUncompressed(terminalPublicKeyData)
    else {
      throw Rejected()
    }
    terminalPublicKey = terminalPoint
    let publicKey = BrainpoolP384r1.multiply(mappedGenerator, by: agreementScalar)
    cardPublicKey = publicKey
    let shared = BrainpoolP384r1.multiply(terminalPoint, by: agreementScalar)
    guard let horizontal = shared.affineX else { throw Rejected() }
    let secret = horizontal.bigEndianBytes()
    let derivedMacKey = Self.derivedKey(from: secret, counter: Self.macCounter)
    macKeyMaterial = derivedMacKey
    sessionKeys = PaceSessionKeys(
      encryptionKey: Self.derivedKey(from: secret, counter: Self.encryptionCounter),
      macKey: derivedMacKey
    )
    return try Self.response(
      contextTag: Self.ephemeralPublicKeyCardTag,
      value: try Self.encodedPoint(publicKey)
    )
  }

  /// Round four: check the terminal's token and answer with the card's.
  private func authenticate(terminalToken: Data) throws -> Data {
    guard
      let cardPublicKey,
      let terminalPublicKey,
      let macKey = macKeyMaterial
    else {
      throw Rejected()
    }
    let expected = try AesCmac.secureMessagingTag(
      key: macKey,
      message: try Self.tokenInput(for: cardPublicKey)
    )
    guard expected == terminalToken else { throw Rejected() }
    let cardToken = try AesCmac.secureMessagingTag(
      key: macKey,
      message: try Self.tokenInput(for: terminalPublicKey)
    )
    return try Self.response(
      contextTag: Self.authenticationTokenCardTag,
      value: cardToken
    )
  }
}
