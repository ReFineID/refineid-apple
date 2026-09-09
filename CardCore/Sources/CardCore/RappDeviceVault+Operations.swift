// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

extension RappDeviceVault {
  /// Writes or replaces one requester journal record for the operation.
  public func persistRequester(
    pairID: Data,
    operationID: Data,
    record: Data
  ) throws {
    try synchronized {
      try requireOperationIdentifiers(pairID: pairID, operationID: operationID)
      guard !record.isEmpty else { throw Failure.malformed }
      try upsert(
        service: operationService(namespace: namespace.requester, pairID: pairID),
        account: operationID.hexadecimal,
        attributes: [kSecValueData as String: record])
    }
  }

  /// Returns all requester journal records stored for the pair.
  public func loadRequester(pairID: Data) throws -> [Data] {
    try synchronized {
      try requireIdentifier(pairID, size: IdentifierSize.pair)
      return try loadAll(
        service: operationService(namespace: namespace.requester, pairID: pairID)
      ).map { item in
        guard let record = item[kSecValueData as String] as? Data, !record.isEmpty else {
          throw Failure.malformed
        }
        return record
      }
    }
  }

  /// Writes the proxy journal record with no retained result.
  public func persistProxy(
    pairID: Data,
    operationID: Data,
    record: Data
  ) throws {
    try persistProxyValue(
      pairID: pairID,
      operationID: operationID,
      record: record,
      retainedResult: .replace(nil))
  }

  /// Writes the proxy journal record together with its retained result.
  public func persistProxyResult(
    pairID: Data,
    operationID: Data,
    record: Data,
    result: Data
  ) throws {
    guard !result.isEmpty else { throw Failure.malformed }
    try persistProxyValue(
      pairID: pairID,
      operationID: operationID,
      record: record,
      retainedResult: .replace(result))
  }

  /// Updates an existing proxy record, preserving its retained result.
  public func retainProxyUncertain(
    pairID: Data,
    operationID: Data,
    record: Data
  ) throws {
    try persistProxyValue(
      pairID: pairID,
      operationID: operationID,
      record: record,
      retainedResult: .preserve)
  }

  /// Replaces the proxy record and discards its retained result.
  public func acknowledgeProxyResult(
    pairID: Data,
    operationID: Data,
    record: Data
  ) throws {
    try persistProxyValue(
      pairID: pairID,
      operationID: operationID,
      record: record,
      retainedResult: .replace(nil))
  }

  /// Returns every stored proxy journal for the pair.
  public func loadProxy(pairID: Data) throws -> [StoredProxyJournal] {
    try synchronized {
      try requireIdentifier(pairID, size: IdentifierSize.pair)
      return try loadAll(
        service: operationService(namespace: namespace.proxy, pairID: pairID)
      ).map { item in
        guard let record = item[kSecAttrGeneric as String] as? Data, !record.isEmpty,
          let result = item[kSecValueData as String] as? Data
        else {
          throw Failure.malformed
        }
        return StoredProxyJournal(
          record: record,
          retainedResult: result.isEmpty || result == StoredValue.noRetainedResult
            ? nil
            : result)
      }
    }
  }

  /// Deletes all requester and proxy journal records for the pair.
  public func removeOperationRecords(pairID: Data) throws {
    try synchronized {
      try requireIdentifier(pairID, size: IdentifierSize.pair)
      try deleteAll(service: operationService(namespace: namespace.requester, pairID: pairID))
      try deleteAll(service: operationService(namespace: namespace.proxy, pairID: pairID))
    }
  }
}
