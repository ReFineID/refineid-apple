// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

@Suite
internal struct ZipReaderTests {
  @Test
  internal func readsStoredEntriesWrittenByZipWriter() throws {
    var writer = AsicContainer.ZipWriter()
    let textContent = Data("Hello, world! This is a test file for ASiC-E.".utf8)
    let binaryContent = Data([0x00, 0xFF, 0x42, 0x13, 0x37, 0xFE, 0xED])

    writer.add(name: "mimetype", content: Data(AsicContainer.mimeType.utf8))
    writer.add(name: "test.txt", content: textContent)
    writer.add(name: "binary.dat", content: binaryContent)

    let archive = try #require(writer.finish())
    let extracted = ZipReader.read(archive: archive)

    #expect(extracted.count == 3)
    #expect(extracted["mimetype"] == Data(AsicContainer.mimeType.utf8))
    #expect(extracted["test.txt"] == textContent)
    #expect(extracted["binary.dat"] == binaryContent)
  }

  @Test
  internal func refusesCorruptOrTruncatedArchives() throws {
    let empty = Data()
    #expect(ZipReader.read(archive: empty).isEmpty)

    let invalidSignature = Data("Not a zip file at all".utf8)
    #expect(ZipReader.read(archive: invalidSignature).isEmpty)

    var writer = AsicContainer.ZipWriter()
    writer.add(name: "hello.txt", content: Data("test".utf8))
    var archive = try #require(writer.finish())
    // Truncate the archive
    archive.removeLast(10)
    #expect(ZipReader.read(archive: archive).isEmpty)
  }
}
