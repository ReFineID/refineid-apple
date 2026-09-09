// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import RappEngine

/// One report line.
internal enum EngineReport {
  internal static func check(_ passed: Bool, _ label: String) {
    #expect(passed, "\(label)")
  }
}
