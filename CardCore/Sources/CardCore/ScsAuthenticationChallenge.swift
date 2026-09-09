// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The origin-bound challenge rule for authentication-key signs.
///
/// The authentication certificate is an authentication-purpose key,
/// so the SCS must refuse to sign arbitrary bytes with it: the
/// content must be `origin;nonce`, where `origin` matches the
/// request's Origin header byte for byte and the nonce is at least
/// 64 octets of caller randomness (DVV SCS specification v1.3 §2.1,
/// §3.7). Without this, any page the holder happens to visit could
/// obtain an authentication signature over bytes of its choosing and
/// replay it elsewhere.
public enum ScsAuthenticationChallenge {
  /// Why `content` is not an acceptable challenge, or nil when it
  /// is.
  public static func refusal(content: Data, origin: String?) -> String? {
    guard let origin else {
      return "missing Origin header"
    }
    guard let text = String(data: content, encoding: .utf8) else {
      return "challenge must be UTF-8 (origin;nonce)"
    }
    guard let separator = text.firstIndex(of: ";") else {
      return "challenge missing ; separator (expected origin;nonce)"
    }
    let challengeOrigin = String(text[text.startIndex..<separator])
    let nonce = text[text.index(after: separator)...]
    guard challengeOrigin == origin else {
      return "challenge origin \(challengeOrigin) does not match request Origin \(origin)"
    }
    guard nonce.count >= ScsValues.nonceMinimumLength else {
      return "challenge nonce too short (\(nonce.count) octets, 64 required)"
    }
    return nil
  }
}
