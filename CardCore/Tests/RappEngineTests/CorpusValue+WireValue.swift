// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

extension CorpusValue {
  /// The wire value this described corpus value denotes.
  internal var wireValue: WireValue {
    switch self {
    case .array(let items):
      .array(items.map(\.wireValue))

    case .bool(let value):
      .boolean(value)

    case .bytes(let value):
      .bytes(value)

    case .map(let entries):
      .map(Dictionary(entries.map { ($0.key, $0.value.wireValue) }) { first, _ in first })

    case .negative(let value):
      .negative(value)

    case .null:
      .null

    case .text(let value):
      .text(value)

    case .unsigned(let value):
      .unsigned(value)
    }
  }

  /// The same value as a body map, for the sections that describe one.
  internal func mapValue(_ label: String) throws -> [String: WireValue] {
    guard case .map(let entries) = wireValue else { throw CorpusError.notAMap(label) }
    return entries
  }
}
