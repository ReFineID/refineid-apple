// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Base64url without padding, the JOSE segment encoding (RFC 7515
/// section 2).
///
/// Deliberately separate from RappEngine's strict base64url: that one
/// implements the RAPP offer encoding, is pinned by the vendored
/// conformance corpus, and refuses what its specification refuses, while
/// this one carries JOSE segments with Foundation's tolerance.
public enum Base64Url {
  /// Encodes without padding.
  public static func encode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// Decodes, restoring padding; nil when the input is not
  /// base64url.
  public static func decode(_ text: String) -> Data? {
    var base64 =
      text
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let block = 4
    let remainder = base64.count % block
    if remainder > 0 {
      base64 += String(repeating: "=", count: block - remainder)
    }
    return Data(base64Encoded: base64)
  }
}
