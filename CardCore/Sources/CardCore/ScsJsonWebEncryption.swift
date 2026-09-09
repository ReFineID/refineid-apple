// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// Compact JWE in the one shape the SCS transaction uses: direct
/// encryption with A256GCM under the transaction key agreed at
/// `begin` (DVV SCS specification v1.3; RFC 7516).
///
/// The protected header is the additional authenticated data, the
/// key segment stays empty (direct encryption), the IV is 96 bits
/// and the tag 128, all base64url.
public enum ScsJsonWebEncryption {
  /// The decoded header fields checked on the way in.
  private struct Header: Codable {
    let alg: String
    let enc: String
  }

  /// The fixed protected header for `alg=dir`, `enc=A256GCM`.
  private static let protectedHeader = Base64Url.encode(
    Data(#"{"alg":"dir","enc":"A256GCM"}"#.utf8)
  )

  /// Decrypts a compact JWE under `key`.
  public static func decrypt(
    compact: Data,
    key: SymmetricKey
  ) -> Result<Data, ScsTransactionError> {
    guard let text = String(data: compact, encoding: .utf8) else {
      return .failure(.badRequest("JWE body is not UTF-8"))
    }
    let parts = text.components(separatedBy: ".")
    guard parts.count == ScsValues.jweSegmentCount, parts[1].isEmpty else {
      return .failure(
        .badRequest("execute transaction must be compact direct-encryption JWE"))
    }
    guard
      let headerData = Base64Url.decode(parts[0]),
      let header = try? JSONDecoder().decode(Header.self, from: headerData),
      header.alg == "dir", header.enc == "A256GCM"
    else {
      return .failure(.badRequest("JWE must use alg=dir and enc=A256GCM"))
    }
    guard
      let initializationVector = Base64Url.decode(
        parts[ScsValues.jweInitializationVectorIndex]),
      initializationVector.count == ScsValues.jweInitializationVectorLength
    else {
      return .failure(.badRequest("JWE IV must be 96 bits of base64url"))
    }
    guard let ciphertext = Base64Url.decode(parts[ScsValues.jweCiphertextIndex]) else {
      return .failure(.badRequest("JWE ciphertext is not base64url"))
    }
    guard
      let tag = Base64Url.decode(parts[ScsValues.jweTagIndex]),
      tag.count == ScsValues.jweTagLength
    else {
      return .failure(.badRequest("JWE authentication tag must be 128 bits of base64url"))
    }
    guard
      let nonce = try? AES.GCM.Nonce(data: initializationVector),
      let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag),
      let plaintext = try? AES.GCM.open(box, using: key, authenticating: Data(parts[0].utf8))
    else {
      return .failure(.forbidden("JWE authentication failed"))
    }
    return .success(plaintext)
  }

  /// Encrypts `plaintext` under `key` into a compact JWE.
  public static func encrypt(
    plaintext: Data,
    key: SymmetricKey
  ) -> Result<String, ScsTransactionError> {
    guard
      let box = try? AES.GCM.seal(
        plaintext,
        using: key,
        authenticating: Data(Self.protectedHeader.utf8)
      )
    else {
      return .failure(.internalError("encrypt transaction response"))
    }
    let initializationVector = box.nonce.withUnsafeBytes { bytes in Data(bytes) }
    let compact =
      Self.protectedHeader + ".." + Base64Url.encode(initializationVector) + "."
      + Base64Url.encode(box.ciphertext) + "." + Base64Url.encode(box.tag)
    return .success(compact)
  }
}
