// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Creation of the signature and widget indirect objects (ISO 32000-1 §12.8, §12.5).
extension PdfIncrementalSigner {
  /// Appends the signature dictionary, answering where its two
  /// placeholders landed.
  internal static func appendSignatureObject(
    into out: inout Data,
    offsets: inout [Int: Int],
    revision: Revision,
    number: Int,
    capacity: Int
  ) -> (byteRangeAt: Int, contentsOpen: Int) {
    offsets[number] = out.count
    out.append(Data(Self.signatureHeader(revision, number: number).utf8))
    let byteRangeAt = out.count + Self.byteRangeArrayPrefix.count
    out.append(Data(Self.byteRangePlaceholder.utf8))
    let contentsOpen = out.count + Self.contentsPrefix.count
    out.append(Data(Self.contentsPlaceholder(capacity: capacity).utf8))
    out.append(Data(">>\nendobj\n".utf8))
    return (byteRangeAt, contentsOpen)
  }

  /// The reserved hex hole, all zero padding until filled.
  internal static func contentsPlaceholder(capacity: Int) -> String {
    let hexLength = capacity * PdfValues.hexCharactersPerByte
    return contentsPrefix + "<" + String(repeating: "0", count: hexLength)
      + ">\n"
  }

  /// Bytes reserved for this revision's structure.
  internal static func capacity(for revision: Revision) -> Int {
    switch revision {
    case .signature:
      PdfValues.signatureCapacity

    case .documentTimestamp:
      PdfValues.timestampCapacity
    }
  }

  /// The signature dictionary up to its byte-range array.
  internal static func signatureHeader(_ revision: Revision, number: Int) -> String {
    guard let claim = revision.signatureClaim else {
      return "\(number) 0 obj\n<< /Type /DocTimeStamp /Filter /Adobe.PPKLite"
        + " /SubFilter /ETSI.RFC3161\n"
    }
    var text = "\(number) 0 obj\n<< /Type /Sig /Filter /Adobe.PPKLite"
    text += " /SubFilter /ETSI.CAdES.detached\n"
    if let reason = claim.reason {
      text += "/Reason (\(Self.escaped(reason)))\n"
    }
    if let location = claim.location {
      text += "/Location (\(Self.escaped(location)))\n"
    }
    text += "/M (\(Self.pdfDate(claim.signedAt)))\n"
    return text
  }

  /// The signature widget dictionary.
  ///
  /// Its name is built from the signature's object number, which is
  /// unique in the document by construction. A fixed name would not
  /// be: two fields with the same fully qualified name are the same
  /// field (ISO 32000-1 §12.7.3.2), so signing a signed document
  /// again would give one name two signature dictionaries.
  internal static func widget(
    _ revision: Revision,
    field: Int,
    signature: Int,
    page: Int,
    showing: (rectangle: String, appearance: Int)?
  ) -> String {
    let name: String
    switch revision {
    case .signature:
      name = "Signature\(signature)"

    case .documentTimestamp:
      name = "Timestamp\(signature)"
    }
    // A field with no appearance is invisible, which is what a
    // document timestamp and an unstamped signature want. One with an
    // appearance names the box it fills and the stream that fills it,
    // and carries the key that lets a later signing count it.
    let visible =
      showing.map { found in
        " /Rect \(found.rectangle) /AP << /N \(found.appearance) 0 R >>"
          + " \(PdfValues.stampMarker) true"
      } ?? " /Rect [0 0 0 0]"
    return "\(field) 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Sig"
      + " /T (\(name)) /V \(signature) 0 R /P \(page) 0 R\(visible) /F 132 >>\nendobj\n"
  }

  /// A literal string's escapes: backslash and both parentheses.
  internal static func escaped(_ text: String) -> String {
    text.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "(", with: "\\(")
      .replacingOccurrences(of: ")", with: "\\)")
  }
}
