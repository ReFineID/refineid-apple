// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Token-safe dictionary rewriting for the document security store.
extension PdfValidationStore {
  /// One top-level key and its value.
  internal struct DictionaryEntry {
    /// The decoded name, without its slash.
    internal let name: String

    /// The name exactly as the document wrote it.
    internal let rawName: String

    /// The exact byte range of the value.
    internal let valueRange: Range<Int>
  }

  /// A parsed PDF dictionary with byte ranges into its original spelling.
  internal struct DictionarySyntax {
    /// The dictionary's bytes.
    private let source: Data

    /// Its top-level entries, in document order.
    internal let entries: [DictionaryEntry]

    /// Where the outer closing marker starts.
    private let closingOffset: Int

    /// Parses exactly one dictionary.
    internal init(_ text: String) throws {
      guard let bytes = text.data(using: .isoLatin1) else {
        throw PdfSigningError.structureUnreadable
      }
      var parser = ValueParser(bytes)
      let parsed = try parser.dictionary()
      try parser.requireEnd()
      self.source = bytes
      self.entries = parsed.entries
      self.closingOffset = parsed.closingOffset
    }

    /// Latin-1 preserves each PDF source byte as one scalar.
    private static func text(_ data: Data) -> String {
      String(data: data, encoding: .isoLatin1) ?? ""
    }

    /// The named top-level entry.
    internal func entry(named name: String) -> DictionaryEntry? {
      entries.first { entry in entry.name == name }
    }

    /// One entry's value exactly as written.
    internal func value(of entry: DictionaryEntry) -> String {
      Self.text(source.subdata(in: entry.valueRange))
    }

    /// Replaces a value, or inserts the entry before the outer close.
    internal func replacing(name: String, value: String) throws -> String {
      var updated = source
      let encoded = Data(value.utf8)
      if let existing = self.entry(named: name) {
        updated.replaceSubrange(existing.valueRange, with: encoded)
      } else {
        updated.insert(
          contentsOf: Data("\n/\(name) \(value)\n".utf8), at: closingOffset
        )
      }
      guard let text = String(data: updated, encoding: .isoLatin1) else {
        throw PdfSigningError.structureUnreadable
      }
      return text
    }
  }
}
