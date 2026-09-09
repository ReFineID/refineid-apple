// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Where operation records are stored, implemented by the caller.
///
/// A record reaches storage before the card is touched, never after, so each
/// call is one atomic storage transaction.
public protocol RappOperationVault: AnyObject, Sendable {
  /// Writes a requester record.
  func persistRequester(pairId: Data, operationId: Data, record: Data) throws

  /// Reads every requester record stored for the pairing.
  func loadRequester(pairId: Data) throws -> [Data]

  /// Writes a proxy record.
  func persistProxy(pairId: Data, operationId: Data, record: Data) throws

  /// Writes a proxy record together with the result it retains, before that
  /// result is released to the transport.
  func persistProxyResult(pairId: Data, operationId: Data, record: Data, result: Data) throws

  /// Marks delivery uncertain while keeping the retained result.
  func retainProxyUncertain(pairId: Data, operationId: Data, record: Data) throws

  /// Marks acknowledgement and erases the retained result.
  func acknowledgeProxyResult(pairId: Data, operationId: Data, record: Data) throws

  /// Reads every proxy record stored for the pairing.
  func loadProxy(pairId: Data) throws -> [RappStoredProxyJournal]
}
