// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// ASiC-E containers: a ZIP holding documents and the XAdES signature
/// over them (ETSI EN 319 162-1).
///
/// Where PAdES puts the signature inside the document, ASiC puts the
/// documents and the signature side by side in one archive. That is
/// the right shape when the document is not a PDF, or when a
/// submission is a set of files one signature should cover.
///
/// # What is actually signed
///
/// The XAdES signature under `META-INF/signatures0.xml` carries one
/// `ds:Reference` per file, so it covers the files directly. The
/// `META-INF/manifest.xml` inventory is a borrowed OpenDocument
/// listing that records media types and is not signed at all; the
/// signed copy of each media type is in the signature's
/// `DataObjectFormat`.
///
/// # The mimetype rule
///
/// EN 319 162-1 annex A.1 requires the first archive entry to be named
/// `mimetype`, stored uncompressed, with no extra field. It exists so
/// a reader can identify the container by reading a fixed offset near
/// the start of the file rather than parsing the ZIP directory. This
/// writer stores every entry uncompressed, which satisfies that rule
/// by construction and keeps the archive verifiable without a
/// decompressor.
///
/// # `.asice` and `.bdoc`
///
/// One writer, because they are one format. BDOC 2.1 is ASiC-E with
/// XAdES - same media type, same entry names, same signature - and
/// the extension is all that differs. Estonian software writes
/// `.bdoc`; the rest of Europe writes `.asice`.
public enum AsicContainer {
  /// One file to be carried and attested.
  public struct DataObject: Equatable, Sendable {
    /// Entry name inside the container.
    ///
    /// Also the reference URI in the signature.
    public let name: String

    /// Media type recorded for the entry, signed in the XAdES
    /// `DataObjectFormat`.
    public let mimeType: String

    /// The file's bytes.
    public let content: Data

    /// Groups one file with the facts the container records about it.
    public init(name: String, mimeType: String, content: Data) {
      self.name = name
      self.mimeType = mimeType
      self.content = content
    }
  }

  /// Media type of an ASiC-E container.
  public static let mimeType = "application/vnd.etsi.asic-e+zip"

  /// Entry name the media type must be stored under, first,
  /// uncompressed (EN 319 162-1 annex A.1).
  internal static let mimetypeEntryName = "mimetype"

  /// Where the unsigned OpenDocument inventory lives
  /// (EN 319 162-1 annex A.5).
  internal static let manifestEntryName = "META-INF/manifest.xml"

  /// Where the XAdES signature lives.
  ///
  /// Numbered, because a container may carry several signatures over
  /// the same files. This writer produces the first.
  internal static let signatureEntryName = "META-INF/signatures0.xml"

  /// OpenDocument manifest namespace, which ASiC reuses rather than
  /// defining its own (EN 319 162-1 annex A.5).
  internal static let manifestNamespace =
    "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"

  /// The folder the container keeps its manifest and signatures in.
  private static let reservedFolderName = "META-INF"

  /// Whether every file can be carried under the name it was given.
  ///
  /// `mimetype` and `META-INF/` belong to the container, and a name
  /// used twice leaves a reader to choose which entry wins. Absolute
  /// paths, parent-directory components, backslashes and control
  /// characters have no one portable archive meaning. Any of them lets
  /// a carried file take the place of a manifest or a signature once
  /// the archive is unpacked, so they are refused rather than mangled
  /// into something unique.
  ///
  /// Asked before the card signs, so a set that cannot be carried
  /// costs no PIN attempt.
  public static func areNamesUsable(_ objects: [DataObject]) -> Bool {
    var seen: Set<String> = []
    for object in objects {
      guard Self.isNameUsable(object.name), seen.insert(object.name).inserted else {
        return false
      }
    }
    return true
  }

  /// Whether one entry name is a name a container may carry.
  private static func isNameUsable(_ name: String) -> Bool {
    let folded = name.lowercased()
    guard !name.isEmpty,
      folded != Self.mimetypeEntryName.lowercased(),
      folded != Self.reservedFolderName.lowercased(),
      !folded.hasPrefix(Self.reservedFolderName.lowercased() + "/"),
      !name.hasPrefix("/"),
      !name.contains("\\"),
      !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    else {
      return false
    }
    return name.split(separator: "/", omittingEmptySubsequences: false)
      .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
  }

  /// Writes the finished `.asice` archive.
  ///
  /// `signatureXml` is a complete `META-INF/signatures0.xml`, as
  /// `XadesSignature.Plan.document` produced it. Entry order is fixed
  /// and load-bearing: `mimetype` first for the reason in the type
  /// docs, then the data objects, then the inventory and the signature
  /// under `META-INF/`. Returns nil when a name cannot be carried, or
  /// when an entry cannot be described by the 32-bit ZIP fields.
  public static func container(
    objects: [DataObject],
    signatureXml: Data
  ) -> Data? {
    guard Self.areNamesUsable(objects) else { return nil }
    var archive = ZipWriter()
    archive.add(name: Self.mimetypeEntryName, content: Data(Self.mimeType.utf8))
    for object in objects {
      archive.add(name: object.name, content: object.content)
    }
    archive.add(name: Self.manifestEntryName, content: Self.manifest(objects))
    archive.add(name: Self.signatureEntryName, content: signatureXml)
    return archive.finish()
  }

  /// The OpenDocument inventory: one entry per file, plus the
  /// container itself.
  ///
  /// Nothing signs this, so it is an aid to readers rather than
  /// evidence. A verifier that trusted a media type from here would be
  /// trusting an unsigned claim; the signed copy is in the signature's
  /// `DataObjectFormat`.
  internal static func manifest(_ objects: [DataObject]) -> Data {
    var out = #"<?xml version="1.0" encoding="UTF-8"?>"# + "\n"
    out += #"<manifest:manifest xmlns:manifest="\#(Self.manifestNamespace)">"#
    out += "\n"
    // The container itself, named by the root path. Required first.
    out += #"  <manifest:file-entry manifest:full-path="/" "#
    out += #"manifest:media-type="\#(Self.mimeType)"/>"# + "\n"
    for object in objects {
      let path = XadesSignature.escapeAttribute(object.name)
      let media = XadesSignature.escapeAttribute(object.mimeType)
      out += #"  <manifest:file-entry manifest:full-path="\#(path)" "#
      out += #"manifest:media-type="\#(media)"/>"# + "\n"
    }
    out += "</manifest:manifest>\n"
    return Data(out.utf8)
  }
}
