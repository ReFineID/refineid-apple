// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation
import Testing

/// Reading the holder's handwritten signature out of a DG7 template
/// (ICAO 9303-10), and refusing what cannot be carried into a
/// document.
@Suite
internal struct DisplayedSignatureTests {
  /// The smallest thing that opens like a JPEG.
  private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])

  /// A JPEG 2000 codestream, which the specification permits and this
  /// does not carry.
  private static let jpeg2000 = Data([0xFF, 0x4F, 0xFF, 0x51, 0x00, 0x29])

  /// A DER element with a one-byte length.
  private static func element(_ tag: [UInt8], _ content: Data) -> Data {
    Data(tag) + Data([UInt8(content.count)]) + content
  }

  /// A DG7 template holding a count and one image.
  private static func dataGroup(
    instances: UInt8,
    image: Data,
    imageTag: [UInt8] = [0x5F, 0x43]
  ) -> Data {
    let body =
      Self.element([0x02], Data([instances]))
      + Self.element(imageTag, image)
    return Self.element([0x67], body)
  }

  @Test
  internal func theSignatureImageIsRead() throws {
    let group = Self.dataGroup(instances: 1, image: Self.jpeg)

    let image = try DisplayedSignature.image(inDataGroup: group)

    #expect(image.bytes == Self.jpeg)
    #expect(image.isJpeg)
  }

  @Test
  internal func aTemplateClaimingNoInstancesIsRefused() {
    // The count is read rather than assumed; a template that says it
    // holds nothing is not quietly read anyway.
    let group = Self.dataGroup(instances: 0, image: Self.jpeg)

    #expect(throws: DisplayedSignature.Failure.notADataGroup) {
      _ = try DisplayedSignature.image(inDataGroup: group)
    }
  }

  @Test
  internal func aJpeg2000ImageIsRefusedRatherThanHalfSupported() {
    // PDF can carry JPEG 2000, but not every reader draws it, and a
    // signature that renders on one machine and not another is worse
    // than none.
    let group = Self.dataGroup(instances: 1, image: Self.jpeg2000)

    #expect(throws: DisplayedSignature.Failure.unsupportedImageFormat) {
      _ = try DisplayedSignature.image(inDataGroup: group)
    }
  }

  @Test
  internal func somethingThatIsNotADataGroupIsRefused() {
    #expect(throws: DisplayedSignature.Failure.notADataGroup) {
      _ = try DisplayedSignature.image(inDataGroup: Data())
    }
    #expect(throws: DisplayedSignature.Failure.notADataGroup) {
      _ = try DisplayedSignature.image(
        inDataGroup: Self.element([0x61], Self.jpeg)
      )
    }
  }

  @Test
  internal func aTemplateWithoutAnImageElementIsRefused() {
    let group = Self.dataGroup(
      instances: 1, image: Self.jpeg, imageTag: [0x5F, 0x2E]
    )

    #expect(throws: DisplayedSignature.Failure.noImage) {
      _ = try DisplayedSignature.image(inDataGroup: group)
    }
  }
}
