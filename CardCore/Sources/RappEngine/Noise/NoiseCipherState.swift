// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// One direction of an established Noise channel.
///
/// The key is set once and the counter advances on every sealed or opened
/// message, so a nonce is never reused within a channel direction.
internal struct NoiseCipherState {
  private var key: SymmetricKey?
  private var counter: UInt64 = 0

  internal var hasKey: Bool { key != nil }

  internal mutating func initializeKey(_ material: Data) {
    key = SymmetricKey(data: material)
    counter = 0
  }

  /// ChaChaPoly takes zero padding followed by the little-endian counter.
  private func nonce(for counter: UInt64) throws -> ChaChaPoly.Nonce {
    var bytes = Data(repeating: 0, count: NoiseSizes.nonceZeroPrefixLength)
    withUnsafeBytes(of: counter.littleEndian) { bytes.append(contentsOf: $0) }
    return try ChaChaPoly.Nonce(data: bytes)
  }

  internal mutating func encrypt(associatedData: Data, plaintext: Data) throws -> Data {
    guard let key else { return plaintext }
    let sealed = try ChaChaPoly.seal(
      plaintext, using: key, nonce: try nonce(for: counter), authenticating: associatedData)
    counter += 1
    return sealed.ciphertext + sealed.tag
  }

  internal mutating func decrypt(associatedData: Data, ciphertext: Data) throws -> Data {
    guard let key else { return ciphertext }
    guard ciphertext.count >= NoiseSizes.tagLength else { throw NoiseError.malformedMessage }
    let bodyLength = ciphertext.count - NoiseSizes.tagLength
    let box = try ChaChaPoly.SealedBox(
      nonce: try nonce(for: counter),
      ciphertext: Data(ciphertext.prefix(bodyLength)),
      tag: Data(ciphertext.suffix(NoiseSizes.tagLength)))
    let plaintext = try ChaChaPoly.open(box, using: key, authenticating: associatedData)
    counter += 1
    return plaintext
  }
}
