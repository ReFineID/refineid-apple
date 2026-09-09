// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The canonical-form spellings: algorithm names, times, and escapes.
extension XadesSignature {
  /// The `SignatureMethod` identifier for the signer's key
  /// (RFC 4051 section 2.3), under the SHA-384 digest the card signs.
  internal static func signatureMethod(_ profile: CardKeyProfile) -> String {
    switch profile {
    case .ecdsaP256, .ecdsaP384:
      "http://www.w3.org/2001/04/xmldsig-more#ecdsa-sha384"

    case .rsa2048, .rsa3072:
      "http://www.w3.org/2001/04/xmldsig-more#rsa-sha384"
    }
  }

  /// `xsd:dateTime` in UTC, which is what `SigningTime` is typed as.
  internal static func dateTime(_ instant: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: instant)
  }

  /// Percent-encodes a container entry name for use as a reference
  /// URI.
  ///
  /// The name goes into `ds:Reference/@URI`, which RFC 3986 reads as a
  /// URI and not as a file name. `a#b.txt` unencoded is the URI `a`
  /// with the fragment `b.txt`, so a verifier digests the wrong file
  /// or none; `?`, space and `%` mislead in the same way. Only the
  /// unreserved set plus `/` survives, which leaves ordinary names
  /// untouched.
  internal static func percentEncodePath(_ name: String) -> String {
    let unreserved = Set(
      """
      ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
      0123456789-._~/
      """.utf8
    )
    var out = ""
    for byte in Data(name.utf8) {
      if unreserved.contains(byte) {
        out.append(Character(Unicode.Scalar(byte)))
      } else {
        out += String(format: "%%%02X", byte)
      }
    }
    return out
  }

  /// Escapes an attribute value the way canonicalisation writes it.
  ///
  /// `&`, `<` and `"`, plus the three whitespace characters a parser
  /// would otherwise fold into spaces. Deliberately *not* `>` or `'`:
  /// both are legal raw in an attribute value, and a canonicaliser
  /// writes them raw. Escaping them anyway yields valid XML whose
  /// canonical form differs from what was written - which is the one
  /// failure this type exists to prevent.
  internal static func escapeAttribute(_ value: String) -> String {
    var out = ""
    for character in value {
      switch character {
      case "&":
        out += "&amp;"

      case "<":
        out += "&lt;"

      case "\"":
        out += "&quot;"

      case "\t":
        out += "&#x9;"

      case "\n":
        out += "&#xA;"

      case "\r":
        out += "&#xD;"

      default:
        out.append(character)
      }
    }
    return out
  }

  /// Escapes text content the way canonicalisation writes it.
  ///
  /// `&`, `<`, `>` and carriage return. `>` is escaped here and not in
  /// an attribute value; the asymmetry is in Canonical XML 1.0
  /// section 2.3 and is not a mistake.
  internal static func escapeText(_ value: String) -> String {
    var out = ""
    for character in value {
      switch character {
      case "&":
        out += "&amp;"

      case "<":
        out += "&lt;"

      case ">":
        out += "&gt;"

      case "\r":
        out += "&#xD;"

      default:
        out.append(character)
      }
    }
    return out
  }
}
