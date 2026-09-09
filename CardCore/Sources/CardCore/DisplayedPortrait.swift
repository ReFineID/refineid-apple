// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The holder's portrait, as the travel-document application stores it
/// in ICAO data group 2.
public enum DisplayedPortrait {
  /// Why DG2 did not yield a portrait the app can draw.
  public enum Failure: Error, Equatable, Sendable {
    /// No supported image marker occurs inside the biometric envelope.
    case noImage

    /// The bytes are not a DG2 template.
    case notADataGroup
  }

  /// Encodings used by Finnish identity-card DG2 files.
  public enum Format: Equatable, Sendable {
    case jpeg
    case jpeg2000
  }

  /// An encoded portrait and its container.
  public struct Image: Equatable, Sendable {
    /// Image bytes from the format marker onward.
    public let bytes: Data

    /// The format identified by that marker.
    public let format: Format
  }

  /// JPEG start-of-image, shared by JFIF and Exif.
  private static let jpegMarker = Data([
    ImageValues.markerIntroducer,
    ImageValues.startOfImage,
    ImageValues.markerIntroducer,
  ])

  /// JPEG 2000 JP2 signature box.
  private static let jpeg2000Marker = Data(ImageValues.jpeg2000Signature)

  /// Extracts the first supported image from the DG2 biometric envelope.
  ///
  /// DG2 contains CBEFF and biometric headers before the encoded image.
  /// The format marker is the narrow boundary that matters to ImageIO;
  /// bytes before it are deliberately not carried into the renderer.
  public static func image(inDataGroup group: Data) throws -> Image {
    let file = IcaoTlv(group)
    guard
      let template = file.outermost,
      template.tag == FineidValues.displayedPortraitTag
    else {
      throw Failure.notADataGroup
    }
    let content = file.content(of: template)
    if let range = content.range(of: Self.jpegMarker) {
      return Image(bytes: Data(content[range.lowerBound...]), format: .jpeg)
    }
    if let range = content.range(of: Self.jpeg2000Marker) {
      return Image(
        bytes: Data(content[range.lowerBound...]), format: .jpeg2000
      )
    }
    throw Failure.noImage
  }
}
