// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A described corpus value, rebuilt as the wire value it denotes.
internal indirect enum CorpusValue: Decodable {
  case array([Self])
  case bool(Bool)
  case bytes(Data)
  case map([CorpusMapEntry])
  case negative(Int64)
  case null
  case text(String)
  case unsigned(UInt64)

  private enum CodingKeys: String, CodingKey {
    case entries = "entries"
    case hex = "hex"
    case items = "items"
    case kind = "kind"
    case value = "value"
  }

  internal init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(String.self, forKey: .kind) {
    case "unsigned":
      self = .unsigned(try container.decode(UInt64.self, forKey: .value))

    case "negative":
      self = .negative(try container.decode(Int64.self, forKey: .value))

    case "bytes":
      self = .bytes(try Data(hex: container.decode(String.self, forKey: .hex)))

    case "text":
      self = .text(try container.decode(String.self, forKey: .value))

    case "array":
      self = .array(try container.decode([Self].self, forKey: .items))

    case "map":
      self = .map(try container.decode([CorpusMapEntry].self, forKey: .entries))

    case "bool":
      self = .bool(try container.decode(Bool.self, forKey: .value))

    case "null":
      self = .null

    case let kind:
      throw DecodingError.dataCorruptedError(
        forKey: .kind, in: container, debugDescription: "Unknown corpus value kind \(kind)")
    }
  }
}
