// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The byte each fixture is filled with, distinct so a mix-up shows.
internal enum EngineFill {
  internal static let operationIdentifier: UInt8 = 0x11
  internal static let secondOperationIdentifier: UInt8 = 0x12
  internal static let pairIdentifier: UInt8 = 0x22
  internal static let sessionIdentifier: UInt8 = 0x33
  internal static let signature: UInt8 = 0x44
  internal static let digest: UInt8 = 0x55

  /// Sizes the fixtures are built at.
  internal static let identifierLength = 16
  internal static let signatureLength = 64
  internal static let digestLength = 32
}
