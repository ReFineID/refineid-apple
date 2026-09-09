// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import zlib

/// Minimal ZIP reader for extracting ASiC-E container contents.
///
/// Supports stored entries (ZIP compression method 0) and deflated entries
/// (ZIP compression method 8) decompressed via zlib with raw RFC 1951 framing.
internal struct ZipReader {
  /// Header information for one central directory file entry.
  private struct EntryHeader {
    let localOffset: Int
    let compressedSize: Int
    let uncompressedSize: Int
    let method: UInt16
    let crc: UInt32
  }

  /// All entries found in the archive, keyed by entry name.
  internal let entries: [String: Data]

  /// Whether the data begins with the standard ZIP local file header signature.
  internal static func hasZipSignature(_ data: Data) -> Bool {
    guard data.count >= ZipValues.localHeaderLength else { return false }
    return readUInt32(from: data, at: 0) == ZipValues.localHeaderSignature
  }

  /// Reads and unpacks all entries from a complete ZIP byte buffer.
  ///
  /// Returns an empty dictionary when the bytes do not form a valid ZIP archive,
  /// the central directory cannot be found, or decompression / CRC fails.
  internal static func read(archive: Data) -> [String: Data] {
    guard let eocdOffset = findEndOfCentralDirectory(in: archive) else {
      return [:]
    }

    guard eocdOffset + ZipValues.eocdRecordLength <= archive.count else { return [:] }
    let entryCount = readUInt16(from: archive, at: eocdOffset + ZipValues.eocdEntryCountOffset)
    let directorySize = Int(
      readUInt32(from: archive, at: eocdOffset + ZipValues.eocdDirectorySizeOffset))
    let directoryOffset = Int(
      readUInt32(from: archive, at: eocdOffset + ZipValues.eocdDirectoryOffsetOffset))

    guard directoryOffset >= 0, directoryOffset + directorySize <= archive.count else {
      return [:]
    }

    var unpacked: [String: Data] = [:]
    var currentOffset = directoryOffset

    for _ in 0..<entryCount {
      guard let entry = readCentralDirectoryEntry(from: archive, at: &currentOffset) else {
        return [:]
      }
      unpacked[entry.name] = entry.data
    }

    return unpacked
  }

  private static func readCentralDirectoryEntry(
    from archive: Data,
    at offset: inout Int
  ) -> (name: String, data: Data)? {
    guard offset + ZipValues.centralDirectoryHeaderLength <= archive.count else { return nil }
    guard readUInt32(from: archive, at: offset) == ZipValues.centralHeaderSignature else {
      return nil
    }

    let header = EntryHeader(
      localOffset: Int(readUInt32(from: archive, at: offset + ZipValues.cdLocalHeaderOffset)),
      compressedSize: Int(readUInt32(from: archive, at: offset + ZipValues.cdCompressedSizeOffset)),
      uncompressedSize: Int(
        readUInt32(from: archive, at: offset + ZipValues.cdUncompressedSizeOffset)),
      method: readUInt16(from: archive, at: offset + ZipValues.cdMethodOffset),
      crc: readUInt32(from: archive, at: offset + ZipValues.cdCrcOffset)
    )

    let nameLength = Int(readUInt16(from: archive, at: offset + ZipValues.cdNameLengthOffset))
    let extraLength = Int(readUInt16(from: archive, at: offset + ZipValues.cdExtraLengthOffset))
    let commentLength = Int(readUInt16(from: archive, at: offset + ZipValues.cdCommentLengthOffset))

    let nameStart = offset + ZipValues.centralDirectoryHeaderLength
    guard nameStart + nameLength <= archive.count else { return nil }
    let nameBytes = archive.subdata(in: nameStart..<(nameStart + nameLength))
    guard
      let name = String(data: nameBytes, encoding: .utf8)
        ?? String(data: nameBytes, encoding: .ascii)
    else {
      return nil
    }

    guard let entryData = extractEntryData(from: archive, header: header) else {
      return nil
    }

    offset += ZipValues.centralDirectoryHeaderLength + nameLength + extraLength + commentLength
    return (name, entryData)
  }

  /// Locates the End of Central Directory record by scanning backwards from the end.
  private static func findEndOfCentralDirectory(in data: Data) -> Int? {
    guard data.count >= ZipValues.eocdRecordLength else { return nil }
    let minSearch = max(0, data.count - ZipValues.eocdSearchLimit)
    var offset = data.count - ZipValues.eocdRecordLength
    while offset >= minSearch {
      if readUInt32(from: data, at: offset) == ZipValues.endOfDirectorySignature {
        return offset
      }
      offset -= 1
    }
    return nil
  }

  /// Extracts and decompresses one entry from its local file header.
  private static func extractEntryData(
    from archive: Data,
    header: EntryHeader
  ) -> Data? {
    guard header.localOffset >= 0, header.localOffset + ZipValues.localHeaderLength <= archive.count
    else {
      return nil
    }
    guard readUInt32(from: archive, at: header.localOffset) == ZipValues.localHeaderSignature else {
      return nil
    }

    let localNameLength = Int(
      readUInt16(from: archive, at: header.localOffset + ZipValues.localNameLengthOffset))
    let localExtraLength = Int(
      readUInt16(from: archive, at: header.localOffset + ZipValues.localExtraLengthOffset))
    let dataStart =
      header.localOffset + ZipValues.localHeaderLength + localNameLength + localExtraLength

    guard dataStart >= 0, dataStart + header.compressedSize <= archive.count else {
      return nil
    }

    let compressedBytes = archive.subdata(in: dataStart..<(dataStart + header.compressedSize))
    let uncompressedBytes: Data

    switch header.method {
    case ZipValues.methodStored:
      guard header.compressedSize == header.uncompressedSize else { return nil }
      uncompressedBytes = compressedBytes

    case ZipValues.methodDeflated:
      guard
        let inflated = decompressDeflate(compressedBytes, uncompressedSize: header.uncompressedSize)
      else {
        return nil
      }
      uncompressedBytes = inflated

    default:
      return nil
    }

    guard AsicContainer.ZipWriter.crc32(uncompressedBytes) == header.crc else {
      return nil
    }

    return uncompressedBytes
  }

  /// Decompresses raw DEFLATE bytes (RFC 1951) using zlib with negative window bits.
  private static func decompressDeflate(_ compressed: Data, uncompressedSize: Int) -> Data? {
    var stream = z_stream()
    let initStatus = inflateInit2_(
      &stream,
      ZipValues.zlibRawDeflateWindowBits,
      ZLIB_VERSION,
      Int32(MemoryLayout<z_stream>.size)
    )
    guard initStatus == Z_OK else { return nil }
    defer { inflateEnd(&stream) }

    var result = Data(count: uncompressedSize)
    let success: Bool = result.withUnsafeMutableBytes { destBuffer in
      compressed.withUnsafeBytes { srcBuffer in
        guard let srcBase = srcBuffer.baseAddress, let destBase = destBuffer.baseAddress else {
          return uncompressedSize == 0
        }
        stream.next_in = UnsafeMutablePointer<Bytef>(
          mutating: srcBase.assumingMemoryBound(to: Bytef.self))
        stream.avail_in = uInt(srcBuffer.count)
        stream.next_out = destBase.assumingMemoryBound(to: Bytef.self)
        stream.avail_out = uInt(destBuffer.count)
        let status = inflate(&stream, Z_FINISH)
        return status == Z_STREAM_END || (status == Z_OK && stream.avail_out == 0)
      }
    }

    guard success else { return nil }
    return result
  }

  private static func readUInt16(from data: Data, at offset: Int) -> UInt16 {
    let start = data.startIndex + offset
    let bytes = data[start..<(start + MemoryLayout<UInt16>.size)]
    return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
  }

  private static func readUInt32(from data: Data, at offset: Int) -> UInt32 {
    let start = data.startIndex + offset
    let bytes = data[start..<(start + MemoryLayout<UInt32>.size)]
    return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
  }
}
