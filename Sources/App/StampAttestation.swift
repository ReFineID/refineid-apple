// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The compact statement signed into a stamp's QR code.
///
/// A generic scanner sees one line of plain text. The prefix, SATU,
/// Unix instant and bounded filename are the exact bytes the card
/// signs. The certificate key ID and Base45 signature follow them.
/// Base45 keeps the complete payload in QR alphanumeric mode.
internal enum StampAttestation {
  /// The versioned statement the card signs.
  internal struct Claim: Equatable, Sendable {
    /// The canonical one-line text.
    internal let text: String

    /// The exact bytes sent through SHA-384 to the card.
    internal var bytes: Data { Data(text.utf8) }
  }

  /// The current wire-format marker.
  private static let prefix = "RID1"

  /// Field separator used by travel-document QR formats.
  private static let separator = "/"

  /// Enough of SHA-256 to distinguish the signer certificate in a
  /// document without putting that certificate in the QR code.
  private static let keyIdBytes = 6

  /// The QR is still compact at this bound, including a worst-case
  /// DER P-384 signature and high error correction.
  internal static let maximumFilenameLength = 48

  /// The longest extension retained when a filename is shortened.
  private static let maximumExtensionLength = 8

  /// A basename and extension make two dot-separated parts.
  private static let filenameWithExtensionPartCount = 2

  /// Characters retained from a filename.
  ///
  /// Slash is deliberately absent because it separates the envelope
  /// fields.
  private static let filenameCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .+-"
  )

  /// Characters a Finnish SATU can contain.
  private static let identifierCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-"
  )

  /// Stable case and folding rules, independent of the user's locale.
  private static let posixLocale = Locale(identifier: "en_US_POSIX")

  /// Builds the exact claim, or nil when the certificate supplied no
  /// usable identifier.
  internal static func claim(
    identifier: String,
    filename: String,
    at instant: Date
  ) -> Claim? {
    let canonicalIdentifier = identifier.uppercased(with: Self.posixLocale)
    guard
      !canonicalIdentifier.isEmpty,
      canonicalIdentifier.unicodeScalars.allSatisfy({ scalar in
        Self.identifierCharacters.contains(scalar)
      })
    else {
      return nil
    }
    let epoch = Int64(instant.timeIntervalSince1970.rounded(.down))
    let canonicalName = Self.canonicalFilename(filename)
    return Claim(
      text: [
        Self.prefix,
        canonicalIdentifier,
        String(epoch),
        canonicalName,
      ].joined(separator: Self.separator)
    )
  }

  /// Appends the certificate selector and detached raw signature.
  internal static func payload(
    claim: Claim,
    signerCertificate: Data,
    signature: Data
  ) -> Data {
    let digest = SHA256.hash(data: signerCertificate)
    let keyId = digest.prefix(Self.keyIdBytes)
      .map { String(format: "%02X", $0) }
      .joined()
    let text = [claim.text, keyId, Base45.encode(signature)]
      .joined(separator: Self.separator)
    return Data(text.utf8)
  }

  /// Filename text that stays readable and keeps Core Image in QR
  /// alphanumeric mode.
  internal static func canonicalFilename(_ filename: String) -> String {
    let leaf = URL(fileURLWithPath: filename).lastPathComponent
    let folded = leaf.folding(
      options: [.diacriticInsensitive, .widthInsensitive],
      locale: Self.posixLocale
    )
    let upper = folded.uppercased(with: Self.posixLocale)
    var canonical = ""
    var replacing = false
    for scalar in upper.unicodeScalars {
      if Self.filenameCharacters.contains(scalar) {
        canonical.unicodeScalars.append(scalar)
        replacing = false
      } else if !replacing {
        canonical.append("-")
        replacing = true
      }
    }
    canonical =
      canonical
      .replacingOccurrences(of: "-.", with: ".")
      .trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
    guard !canonical.isEmpty else { return "DOCUMENT" }
    return Self.bounded(canonical)
  }

  /// Truncates the basename while retaining a short extension.
  private static func bounded(_ filename: String) -> String {
    guard filename.count > Self.maximumFilenameLength else { return filename }
    let parts = filename.split(separator: ".", omittingEmptySubsequences: false)
    guard
      let extensionPart = parts.last,
      parts.count >= Self.filenameWithExtensionPartCount,
      !extensionPart.isEmpty,
      extensionPart.count <= Self.maximumExtensionLength
    else {
      return String(filename.prefix(Self.maximumFilenameLength))
    }
    let suffix = ".\(extensionPart)"
    let basenameRoom = Self.maximumFilenameLength - suffix.count
    let basename =
      filename
      .dropLast(suffix.count)
      .prefix(basenameRoom)
      .trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
    return String(basename) + suffix
  }
}
