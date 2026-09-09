// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Compression
import Foundation

/// FlateDecode: the deflate filter PDF compresses structures with
/// (ISO 32000-1 §7.4.4; RFC 1950 wrapper, RFC 1951 body).
internal enum FlateDecoder {
  /// Bytes in the RFC 1950 wrapper's header.
  private static let headerLength = 2

  /// The method nibble deflate uses in the header's first byte.
  private static let deflateMethod = 8

  /// Mask selecting the method nibble.
  private static let methodMask = 15

  /// The header bit announcing a preset dictionary, which FlateDecode
  /// never uses.
  private static let presetDictionaryBit = 32

  /// The modulus the header's check word satisfies.
  private static let checkModulus = 31

  /// Bytes drained from the decoder per round.
  private static let chunkLength = 65_536

  /// Inflates `input`, refusing output beyond `limit` bytes.
  ///
  /// The wrapper is stripped and the body decoded raw, so the
  /// trailing Adler-32 is not verified - which also accepts the bare
  /// deflate body some writers emit.
  internal static func decoded(_ input: Data, limit: Int) -> Data? {
    guard let body = Self.deflateBody(of: input) else { return nil }
    return Self.inflated(body, limit: limit)
  }

  /// The deflate body inside `input`, unwrapped when an RFC 1950
  /// header leads it.
  private static func deflateBody(of input: Data) -> Data? {
    guard input.count >= Self.headerLength else { return nil }
    let first = Int(input[input.startIndex])
    let second = Int(input[input.startIndex + 1])
    let checkWord = (first << UInt8.bitWidth) | second
    let isWrapped =
      (first & Self.methodMask) == Self.deflateMethod
      && checkWord.isMultiple(of: Self.checkModulus)
    guard isWrapped else { return input }
    guard second & Self.presetDictionaryBit == 0 else { return nil }
    return input.dropFirst(Self.headerLength)
  }

  /// Runs the raw-deflate decoder, growing the output chunk by chunk.
  private static func inflated(_ body: Data, limit: Int) -> Data? {
    var output = Data()
    let stream = UnsafeMutablePointer<compression_stream>.allocate(
      capacity: 1
    )
    defer { stream.deallocate() }
    let opened = compression_stream_init(
      stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB
    )
    guard opened == COMPRESSION_STATUS_OK else { return nil }
    defer { compression_stream_destroy(stream) }
    let finished = body.withUnsafeBytes { raw in
      Self.drain(stream, source: raw, into: &output, limit: limit)
    }
    return finished ? output : nil
  }

  /// Feeds the whole source and drains until the stream ends.
  private static func drain(
    _ stream: UnsafeMutablePointer<compression_stream>,
    source: UnsafeRawBufferPointer,
    into output: inout Data,
    limit: Int
  ) -> Bool {
    guard
      let base = source.bindMemory(to: UInt8.self).baseAddress
    else {
      return false
    }
    let buffer = UnsafeMutablePointer<UInt8>.allocate(
      capacity: Self.chunkLength
    )
    defer { buffer.deallocate() }
    stream.pointee.src_ptr = base
    stream.pointee.src_size = source.count
    while true {
      stream.pointee.dst_ptr = buffer
      stream.pointee.dst_size = Self.chunkLength
      let status = compression_stream_process(
        stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
      )
      guard
        status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END
      else {
        return false
      }
      let produced = Self.chunkLength - stream.pointee.dst_size
      output.append(buffer, count: produced)
      guard output.count <= limit else { return false }
      if status == COMPRESSION_STATUS_END {
        return true
      }
      // A round that consumed everything and produced nothing means
      // the body was truncated; stop rather than spin.
      if produced == 0, stream.pointee.src_size == 0 {
        return false
      }
    }
  }
}
