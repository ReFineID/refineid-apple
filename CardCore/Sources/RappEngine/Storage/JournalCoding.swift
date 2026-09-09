// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

internal func decodedMap(_ bytes: Data) throws -> [String: WireValue] {
  guard let decoded = try? decodeDeterministicCbor(bytes), case .map(let map) = decoded else {
    throw PairRecordError.invalidInput
  }
  return map
}

/// Encodes a card result as the journal stores it.
///
/// The journal names the variant `kind` and carries certificate bytes under
/// `bytes`, while the wire body names the variant `type` and uses `der`. The
/// two encodings are deliberately separate and must not be interchanged.
internal func journalResultValue(_ result: CardOperationResult) -> WireValue {
  switch result {
  case .inspection(let inspection):
    return .map([
      "kind": .text("inspection"),
      "pin1_factory": .boolean(inspection.pin1Factory),
      "pin2_factory": .boolean(inspection.pin2Factory),
      "pin1_attempts": attemptValue(inspection.pin1Attempts),
      "pin2_attempts": attemptValue(inspection.pin2Attempts),
      "puk_attempts": attemptValue(inspection.pukAttempts),
    ])

  case .identity(let displayName, let personIdentifier):
    return .map([
      "kind": .text("identity"),
      "display_name": .text(displayName),
      "person_id": .text(personIdentifier),
    ])

  case .certificate(let bytes, let cardSerial):
    var map: [String: WireValue] = ["kind": .text("certificate"), "bytes": .bytes(bytes)]
    if let cardSerial {
      map["card_serial"] = .text(cardSerial)
    }
    return .map(map)

  case .signature(let bytes):
    return .map(["kind": .text("signature"), "bytes": .bytes(bytes)])
  }
}

internal func journalResultFrom(_ value: WireValue) throws -> CardOperationResult {
  guard case .map(var map) = value else { throw PairRecordError.invalidInput }
  let result: CardOperationResult
  switch try takeText(&map, "kind") {
  case "inspection":
    result = .inspection(try inspectionFrom(&map))

  case "identity":
    result = .identity(
      displayName: try takeText(&map, "display_name"),
      personIdentifier: try takeText(&map, "person_id"))

  case "certificate":
    let bytes = try takeBytes(&map, "bytes")
    let cardSerial: String?
    if let val = map.removeValue(forKey: "card_serial") {
      guard case .text(let str) = val else { throw PairRecordError.invalidInput }
      cardSerial = str
    } else {
      cardSerial = nil
    }
    result = .certificate(bytes, cardSerial: cardSerial)

  case "signature":
    result = .signature(try takeBytes(&map, "bytes"))

  default:
    throw PairRecordError.invalidInput
  }
  guard map.isEmpty else { throw PairRecordError.invalidInput }
  return result
}

internal func wireResultBody(_ result: CardOperationResult) -> [String: WireValue] {
  switch result {
  case .inspection(let inspection):
    return [
      "type": .text("inspection"),
      "pin1_factory": .boolean(inspection.pin1Factory),
      "pin2_factory": .boolean(inspection.pin2Factory),
      "pin1_attempts": attemptValue(inspection.pin1Attempts),
      "pin2_attempts": attemptValue(inspection.pin2Attempts),
      "puk_attempts": attemptValue(inspection.pukAttempts),
    ]

  case .identity(let displayName, let personIdentifier):
    return [
      "type": .text("identity"),
      "display_name": .text(displayName),
      "person_id": .text(personIdentifier),
    ]

  case .certificate(let bytes, let cardSerial):
    var map: [String: WireValue] = ["type": .text("certificate"), "der": .bytes(bytes)]
    if let cardSerial {
      map["card_serial"] = .text(cardSerial)
    }
    return map

  case .signature(let bytes):
    return ["type": .text("signature"), "bytes": .bytes(bytes)]
  }
}

internal func wireResultFrom(
  _ body: [String: WireValue]
) throws -> CardOperationResult {
  var map = body
  let result: CardOperationResult
  switch try takeText(&map, "type") {
  case "inspection":
    result = .inspection(try inspectionFrom(&map))

  case "identity":
    result = .identity(
      displayName: try takeText(&map, "display_name"),
      personIdentifier: try takeText(&map, "person_id"))

  case "certificate":
    let der = try takeBytes(&map, "der")
    let cardSerial: String?
    if let val = map.removeValue(forKey: "card_serial") {
      guard case .text(let str) = val else { throw PairRecordError.invalidInput }
      cardSerial = str
    } else {
      cardSerial = nil
    }
    result = .certificate(der, cardSerial: cardSerial)

  case "signature":
    result = .signature(try takeBytes(&map, "bytes"))

  default:
    throw PairRecordError.invalidInput
  }
  guard map.isEmpty else { throw PairRecordError.invalidInput }
  return result
}

internal func inspectionFrom(_ map: inout [String: WireValue]) throws -> CardInspection {
  CardInspection(
    pin1Factory: try takeBoolean(&map, "pin1_factory"),
    pin2Factory: try takeBoolean(&map, "pin2_factory"),
    pin1Attempts: try takeAttempt(&map, "pin1_attempts"),
    pin2Attempts: try takeAttempt(&map, "pin2_attempts"),
    pukAttempts: try takeAttempt(&map, "puk_attempts")
  )
}

internal func statusReportValue(_ report: StatusReport) -> WireValue {
  .map([
    "operation_id": .bytes(report.operationIdentifier),
    "known": .boolean(report.known),
    "state": report.state.map { .text($0.rawValue) } ?? .null,
    "request_hash": report.requestHash.map { .bytes($0) } ?? .null,
  ])
}

/// The operation state a status report names, absent when stored as null.
private func takeReportedState(_ map: inout [String: WireValue]) throws -> OperationState? {
  switch try takeStoredValue(&map, "state") {
  case .null:
    return nil

  case .text(let name):
    guard let parsed = OperationState(rawValue: name) else { throw PairRecordError.invalidInput }
    return parsed

  default:
    throw PairRecordError.invalidInput
  }
}

/// The request hash a status report names, absent when stored as null.
private func takeReportedRequestHash(_ map: inout [String: WireValue]) throws -> Data? {
  switch try takeStoredValue(&map, "request_hash") {
  case .null:
    return nil

  case .bytes(let bytes):
    guard bytes.count == JournalSize.requestHash else { throw PairRecordError.invalidInput }
    return bytes

  default:
    throw PairRecordError.invalidInput
  }
}

internal func statusReportFrom(_ value: WireValue) throws -> StatusReport {
  guard case .map(var map) = value else { throw PairRecordError.invalidInput }
  let operationIdentifier = try takeBytes(&map, "operation_id")
  guard operationIdentifier.count == JournalSize.operationIdentifier else {
    throw PairRecordError.invalidInput
  }
  let known = try takeBoolean(&map, "known")
  let state = try takeReportedState(&map)
  let requestHash = try takeReportedRequestHash(&map)
  guard map.isEmpty else { throw PairRecordError.invalidInput }
  return StatusReport(
    operationIdentifier: operationIdentifier, known: known, state: state, requestHash: requestHash)
}

/// An absent attempt counter is stored as null rather than omitted.
internal func attemptValue(_ attempts: UInt8?) -> WireValue {
  attempts.map { .unsigned(UInt64($0)) } ?? .null
}

internal func takeAttempt(
  _ map: inout [String: WireValue], _ field: String
) throws -> UInt8? {
  switch try takeStoredValue(&map, field) {
  case .null:
    return nil

  case .unsigned(let value):
    guard let narrowed = UInt8(exactly: value) else { throw PairRecordError.invalidInput }
    return narrowed

  default:
    throw PairRecordError.invalidInput
  }
}
