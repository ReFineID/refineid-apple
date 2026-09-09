// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Translates between sealed session frames and typed messages.
///
/// Only an authenticated envelope reaches this point, so a body that does not
/// parse here is an authenticated peer sending something the protocol forbids.
internal enum SessionMessageCodec {
  /// The typed message an authenticated envelope carries.
  internal static func message(
    from envelope: Envelope,
    pairIdentifier: Data,
    sessionIdentifier: Data,
    nowMilliseconds: UInt64
  ) throws -> TypedMessage {
    switch envelope.messageType {
    case .operationRequest:
      return .operationRequest(
        try OperationRequest.from(
          wireBody: envelope.body,
          pairIdentifier: pairIdentifier,
          sessionIdentifier: sessionIdentifier,
          localStartMilliseconds: nowMilliseconds))

    case .operationPrepared:
      return .operationPrepared(try OperationReference.from(wireBody: envelope.body))

    case .operationCommit:
      return .operationCommit(try OperationReference.from(wireBody: envelope.body))

    case .operationResultAck:
      return .operationResultAck(try OperationReference.from(wireBody: envelope.body))

    case .operationCancel:
      return .operationCancel(try CancelMessage.from(wireBody: envelope.body))

    case .operationResult:
      return .operationResult(
        try OperationResultMessage.decode(try WireValue.map(envelope.body).encoded()))

    case .operationStatus:
      return .operationStatus(try statusReportFrom(.map(envelope.body)))

    case .operationStatusRequest:
      var body = envelope.body
      return .operationStatusRequest(operationIdentifier: try takeBytes(&body, "operation_id"))

    case .error:
      return .error(try protocolError(from: envelope.body))

    default:
      return .other(envelope.messageType)
    }
  }

  /// The registered protocol error an authenticated body names.
  private static func protocolError(from body: [String: WireValue]) throws -> ProtocolErrorMessage {
    var remaining = body
    let name = try takeText(&remaining, "error")
    switch name {
    case EngineErrorName.busy:
      return .busy

    case EngineErrorName.unknownOperation:
      guard case .bytes(let operationIdentifier)? = remaining["operation_id"] else {
        return .unknownOperation(operationIdentifier: nil)
      }
      return .unknownOperation(operationIdentifier: operationIdentifier)

    default:
      throw EngineError.invalidLocalValue
    }
  }

  /// The sealed frame a typed message becomes.
  internal static func frame(
    for message: TypedMessage,
    session: inout EstablishedSession
  ) throws -> Data {
    guard let messageType = message.messageType, let body = try message.wireBody() else {
      throw EngineError.invalidLocalValue
    }
    return try session.seal(messageType, body: body)
  }
}
