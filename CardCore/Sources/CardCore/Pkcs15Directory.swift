// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What a card says about its own objects, read from its PKCS#15
/// directories instead of from known file identifiers.
///
/// EF.ODF names where the certificate and private-key directories
/// live; each of those lists its objects with a common identifier, and
/// a certificate belongs to the key that carries the same one. The key
/// entry also carries the reference the card selects that key by, which
/// is the value MSE:SET needs and which nothing outside the card
/// defines (FINEID S1 v4.2: the reference is derived from
/// PrivateKeyAttributes.keyReference).
public enum Pkcs15Directory {
  /// One certificate the card lists.
  public struct Certificate: Equatable, Sendable {
    /// The label the card publishes for it.
    public let label: String

    /// The identifier shared with the key it belongs to.
    public let identifier: Data

    /// The elementary file holding the certificate.
    public let file: FileIdentifier
  }

  /// One private key the card lists.
  public struct PrivateKey: Equatable, Sendable {
    /// The label the card publishes for it.
    public let label: String

    /// The identifier shared with the certificate it signs for.
    public let identifier: Data

    /// The reference the card selects this key by, absent when the
    /// card leaves the optional field out.
    public let keyReference: UInt8?
  }

  /// Where EF.ODF says the directories are.
  public struct Locations: Equatable, Sendable {
    /// The certificate directory file.
    public let certificates: FileIdentifier?

    /// The private-key directory file.
    public let privateKeys: FileIdentifier?
  }

  /// Bytes in a file identifier.
  private static let fileIdentifierOctets = 2

  /// Bit positions the high octet of a file identifier occupies.
  private static let highOctetShift: UInt16 = 8

  /// Reads EF.ODF and answers where the directories live.
  ///
  /// A path names a file by its trailing identifier; the leading
  /// components repeat the application the reader has already
  /// selected.
  public static func locations(fromObjectDirectory data: Data) -> Locations {
    var certificates: FileIdentifier?
    var privateKeys: FileIdentifier?
    for entry in (try? DerTlvRecord.sequence(in: data)) ?? [] {
      let isDirectoryEntry =
        entry.tag == Pkcs15Values.certificatesTag
        || entry.tag == Pkcs15Values.privateKeysTag
      guard isDirectoryEntry,
        let path = try? DerTlvRecord.sequence(in: entry.value).first,
        path.tag == Pkcs15Values.sequenceTag,
        let octets = try? DerTlvRecord.sequence(in: path.value).first,
        octets.tag == Pkcs15Values.octetStringTag,
        let file = fileIdentifier(fromPath: octets.value)
      else { continue }
      if entry.tag == Pkcs15Values.certificatesTag {
        certificates = file
      } else {
        privateKeys = file
      }
    }
    return Locations(certificates: certificates, privateKeys: privateKeys)
  }

  /// Reads the certificate directory.
  public static func certificates(fromDirectory data: Data) -> [Certificate] {
    entries(in: data).compactMap { entry in
      guard let common = commonAttributes(in: entry),
        let file = certificateFile(in: entry)
      else { return nil }
      return Certificate(
        label: common.label, identifier: common.identifier, file: file)
    }
  }

  /// Reads the private-key directory.
  public static func privateKeys(fromDirectory data: Data) -> [PrivateKey] {
    entries(in: data).compactMap { entry in
      guard let common = commonAttributes(in: entry) else { return nil }
      return PrivateKey(
        label: common.label,
        identifier: common.identifier,
        keyReference: keyReference(in: entry))
    }
  }

  /// The records of one directory file, ignoring padding the card
  /// leaves after the last one.
  private static func entries(in data: Data) -> [DerTlvRecord] {
    ((try? DerTlvRecord.sequence(in: data)) ?? []).filter { record in
      let isContextTag =
        record.tag & Pkcs15Values.contextTagMask == Pkcs15Values.contextTagValue
      return record.tag == Pkcs15Values.sequenceTag || isContextTag
    }
  }

  /// The label and identifier every object entry carries: the label
  /// from its common object attributes, the identifier from the class
  /// attributes that follow.
  private static func commonAttributes(
    in entry: DerTlvRecord
  ) -> (label: String, identifier: Data)? {
    let fields = (try? DerTlvRecord.sequence(in: entry.value)) ?? []
    guard let objectAttributes = fields.first, objectAttributes.tag == Pkcs15Values.sequenceTag,
      let labelRecord = (try? DerTlvRecord.sequence(in: objectAttributes.value))?.first,
      labelRecord.tag == Pkcs15Values.utf8StringTag,
      let label = String(data: labelRecord.value, encoding: .utf8),
      fields.count > 1,
      let identifier = (try? DerTlvRecord.sequence(in: fields[1].value))?.first,
      identifier.tag == Pkcs15Values.octetStringTag
    else { return nil }
    return (label, identifier.value)
  }

  /// The elementary file a certificate entry points at.
  ///
  /// The type attributes hold the certificate's own attributes, which
  /// hold the path, which holds the octets: three descents, because a
  /// PKCS#15 path is a structure and not a bare string.
  private static func certificateFile(in entry: DerTlvRecord) -> FileIdentifier? {
    let fields = (try? DerTlvRecord.sequence(in: entry.value)) ?? []
    guard let typeAttributes = fields.first(where: { $0.tag == Pkcs15Values.typeAttributesTag }),
      let attributes = (try? DerTlvRecord.sequence(in: typeAttributes.value))?.first,
      let path = (try? DerTlvRecord.sequence(in: attributes.value))?.first,
      let octets = (try? DerTlvRecord.sequence(in: path.value))?.first,
      octets.tag == Pkcs15Values.octetStringTag
    else { return nil }
    return fileIdentifier(fromPath: octets.value)
  }

  /// The key reference a private-key entry carries, when it has one.
  ///
  /// It is the last INTEGER of the class attributes, which precede the
  /// type attributes; the fields before it are the identifier, the
  /// usage flags and the native marker.
  private static func keyReference(in entry: DerTlvRecord) -> UInt8? {
    let fields = (try? DerTlvRecord.sequence(in: entry.value)) ?? []
    guard fields.count > 1,
      let attributes = try? DerTlvRecord.sequence(in: fields[1].value),
      let reference = attributes.last(where: { $0.tag == Pkcs15Values.integerTag }),
      reference.value.count == 1
    else { return nil }
    return reference.value.first
  }

  /// The file a PKCS#15 path names: its trailing identifier.
  private static func fileIdentifier(fromPath path: Data) -> FileIdentifier? {
    guard path.count >= fileIdentifierOctets else { return nil }
    let trailing = path.suffix(fileIdentifierOctets)
    guard let high = trailing.first, let low = trailing.last else { return nil }
    return FileIdentifier(value: UInt16(high) << highOctetShift | UInt16(low))
  }
}
