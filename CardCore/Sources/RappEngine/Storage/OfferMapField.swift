// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

internal func offerTakeValue(
  _ map: inout [String: WireValue], _ field: String
) throws -> WireValue {
  guard let value = map.removeValue(forKey: field) else {
    throw PairingOfferError.missingField(field)
  }
  return value
}

internal func offerTakeText(_ map: inout [String: WireValue], _ field: String) throws -> String {
  guard case .text(let value) = try offerTakeValue(&map, field) else {
    throw PairingOfferError.wrongType
  }
  return value
}

internal func offerTakeBytes(_ map: inout [String: WireValue], _ field: String) throws -> Data {
  guard case .bytes(let value) = try offerTakeValue(&map, field) else {
    throw PairingOfferError.wrongType
  }
  return value
}

internal func offerTakeArray(
  _ map: inout [String: WireValue], _ field: String
) throws -> [WireValue] {
  guard case .array(let value) = try offerTakeValue(&map, field) else {
    throw PairingOfferError.wrongType
  }
  return value
}

internal func offerTakeTextArray(
  _ map: inout [String: WireValue], _ field: String
) throws -> [String] {
  try offerTakeArray(&map, field).map { value in
    guard case .text(let text) = value else { throw PairingOfferError.wrongType }
    return text
  }
}

internal func offerTakeUnsigned(
  _ map: inout [String: WireValue], _ field: String
) throws -> UInt64 {
  guard case .unsigned(let value) = try offerTakeValue(&map, field) else {
    throw PairingOfferError.wrongType
  }
  return value
}
