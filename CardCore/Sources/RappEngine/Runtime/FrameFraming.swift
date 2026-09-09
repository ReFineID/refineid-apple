// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The byte-stream framing that delimits frames on a stream transport.
///
/// The length prefix is two bytes, so the largest length it can express is
/// exactly the frame limit: an oversized frame is unrepresentable rather than
/// merely rejected. A declared length is read and checked before its body is
/// read, so an attacker cannot induce a large allocation and no key is
/// touched until the frame is known to be admissible.
internal enum FrameFraming {
  /// Bytes in the length prefix.
  internal static let lengthPrefixBytes = 2

  /// Encodes one frame as its length prefix followed by its bytes.
  internal static func encode(_ frame: BinaryFrame) -> Data {
    var encoded = Data(capacity: lengthPrefixBytes + frame.count)
    let declared = UInt16(frame.count)
    encoded.append(UInt8(truncatingIfNeeded: declared >> UInt8.bitWidth))
    encoded.append(UInt8(truncatingIfNeeded: declared))
    encoded.append(frame.bytes)
    return encoded
  }

  /// Reads the declared body length from a complete prefix.
  internal static func declaredLength(prefix: Data) throws -> Int {
    guard prefix.count == lengthPrefixBytes else {
      throw RappFrameError.oversized(got: prefix.count, maximum: lengthPrefixBytes)
    }
    let high = Int(prefix[prefix.startIndex])
    let low = Int(prefix[prefix.index(after: prefix.startIndex)])
    return (high << UInt8.bitWidth) | low
  }

  /// Decodes one complete framed message, returning the frame and the bytes
  /// that follow it.
  ///
  /// Returns nil while fewer bytes than the frame needs have arrived, which
  /// is an ordinary partial read rather than a failure.
  internal static func decode(_ stream: Data) throws -> (frame: BinaryFrame, rest: Data)? {
    guard stream.count >= lengthPrefixBytes else { return nil }
    let prefixEnd = stream.index(stream.startIndex, offsetBy: lengthPrefixBytes)
    let length = try declaredLength(prefix: stream[stream.startIndex..<prefixEnd])
    guard stream.count - lengthPrefixBytes >= length else { return nil }
    let bodyEnd = stream.index(prefixEnd, offsetBy: length)
    let frame = try BinaryFrame(reconstructing: Data(stream[prefixEnd..<bodyEnd]))
    return (frame, Data(stream[bodyEnd...]))
  }
}
