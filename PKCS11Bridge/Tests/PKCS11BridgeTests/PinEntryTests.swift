// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import PKCS11Bridge
import Testing

@Suite
internal struct PinEntryTests {
  @Test
  internal func defaultsToGraphicalEntry() {
    #expect(PinEntry.resolve(nil) == .graphical)
    #expect(PinEntry.resolve("") == .graphical)
    #expect(PinEntry.resolve("graphical") == .graphical)
  }

  @Test
  internal func selectsTextualEntry() {
    #expect(PinEntry.resolve("textual") == .textual)
    #expect(PinEntry.resolve("TEXTUAL") == .textual)
  }

  @Test
  internal func keepsTheDefaultForUnrecognizedValues() {
    #expect(PinEntry.resolve("tty") == .graphical)
    #expect(PinEntry.resolve("1") == .graphical)
    #expect(PinEntry.resolve("terminal") == .graphical)
  }
}
