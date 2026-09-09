// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The holder's handwritten signature, as the travel-document
/// application stores it (ICAO 9303-10, data group 7).
///
/// DG7 is a template holding a count and that many images. The count
/// is read rather than assumed: the encoding permits several, a
/// Finnish card carries one, and a reader that took the first without
/// looking would be right by luck.
public enum DisplayedSignature {
  /// What a data group said, when it did not say an image.
  public enum Failure: Error, Equatable, Sendable {
    /// The template holds no image.
    case noImage

    /// The bytes are not a DG7 template.
    case notADataGroup

    /// The image is in an encoding this does not carry into a
    /// document.
    case unsupportedImageFormat
  }

  /// An image and what it is encoded as.
  public struct Image: Equatable, Sendable {
    /// The encoded image bytes, exactly as the card stores them.
    public let bytes: Data

    /// Whether those bytes are JPEG, which embeds into a PDF
    /// unchanged.
    public let isJpeg: Bool
  }

  /// The bytes a JPEG opens with, JFIF and Exif alike: the
  /// start-of-image marker followed by the first segment's own.
  private static let jpegMarker: [UInt8] = [
    ImageValues.markerIntroducer,
    ImageValues.startOfImage,
    ImageValues.markerIntroducer,
  ]

  /// The image out of a DG7 template.
  ///
  /// JPEG is the format that matters: a PDF embeds it verbatim, with
  /// no decoding and no re-encoding. JPEG 2000 is permitted by the
  /// specification and is refused here rather than half-supported -
  /// PDF can carry it, but not every reader draws it, and a signature
  /// that renders on one machine and not another is worse than none.
  ///
  /// The walk is written out rather than handed to `DerReader`
  /// because the image is tagged `5F 43`, the high-tag-number form:
  /// a reader that takes one byte as the tag would read `43` as the
  /// length and parse nonsense confidently.
  public static func image(inDataGroup group: Data) throws -> Image {
    let file = IcaoTlv(group)
    guard
      let template = file.outermost,
      template.tag == FineidValues.displayedSignatureTag
    else {
      throw Failure.notADataGroup
    }
    let fields = file.records(within: template.content)
    guard
      let count = fields.first(where: { record in
        record.tag == DerValues.tagInteger && !record.hasTwoByteTag
      }),
      let instances = file.content(of: count).first,
      instances > 0
    else {
      throw Failure.notADataGroup
    }
    guard
      let image = fields.first(where: { record in
        record.hasTwoByteTag && record.tag == FineidValues.biometricImageTag
      })
    else {
      throw Failure.noImage
    }
    let encoded = file.content(of: image)
    guard Self.isJpeg(encoded) else {
      throw Failure.unsupportedImageFormat
    }
    return Image(bytes: encoded, isJpeg: true)
  }

  /// Whether the bytes open as JFIF or Exif JPEG.
  private static func isJpeg(_ bytes: Data) -> Bool {
    guard bytes.count > Self.jpegMarker.count else { return false }
    return Array(bytes.prefix(Self.jpegMarker.count)) == Self.jpegMarker
  }
}
