// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// Fixed identifiers, so every hash in the harness is reproducible.
internal enum OperationFixture {
  internal static let pairIdentifier = Data(
    repeating: OperationFill.pairIdentifier, count: OperationSize.pairIdentifier)
  internal static let sessionIdentifier = Data(
    repeating: OperationFill.sessionIdentifier, count: OperationSize.sessionIdentifier)
  internal static let otherSession = Data(
    repeating: OperationFill.otherSession, count: OperationSize.sessionIdentifier)
  internal static let operationIdentifier = Data(
    repeating: OperationFill.operationIdentifier, count: OperationSize.operationIdentifier)
  internal static let otherOperation = Data(
    repeating: OperationFill.otherOperation, count: OperationSize.operationIdentifier)
  internal static let digest = Data(repeating: OperationFill.digest, count: DigestLength.sha256)
  internal static let otherDigest = Data(
    repeating: OperationFill.otherDigest, count: DigestLength.sha256)
  internal static let signature = Data(
    repeating: OperationFill.signature, count: OperationFill.signatureLength)
  internal static let certificate = Data(
    repeating: OperationFill.certificate, count: OperationFill.certificateLength)
  internal static let origin = "https://example.test"
  internal static let startMilliseconds: UInt64 = 1_000
  internal static let lifetimeMilliseconds: UInt64 = 120_000
  internal static let maximumLifetimeMilliseconds: UInt64 = 300_000
  internal static let approvalMilliseconds: UInt64 = 1_500
}
