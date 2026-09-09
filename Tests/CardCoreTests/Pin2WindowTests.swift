// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Testing

@testable import CardCore

/// What the PIN2 window is allowed to remember, and for how long.
///
/// A credential held in memory earns its tests. The rules here are the
/// ones that decide whether holding it is defensible at all: it lasts a
/// minute, the minute runs from the entry rather than from the last
/// use, and anything that goes wrong ends it.
internal struct Pin2WindowTests {
  /// Digits that are not anyone's PIN; nothing here reaches a card.
  private static let entry = "0000"

  @Test
  internal func holdsAnEntryForTheWindow() {
    var window = Pin2Window()
    window.hold(Self.entry)
    #expect(window.current() == Self.entry)
  }

  @Test
  internal func servesTheSameEntryMoreThanOnce() {
    // The whole point: a batch of documents, one prompt.
    var window = Pin2Window()
    window.hold(Self.entry)
    #expect(window.current() != nil)
    #expect(window.current() != nil)
  }

  @Test
  internal func forgetsWhenTheWindowCloses() {
    var window = Pin2Window()
    window.hold(Self.entry)
    let afterwards = Date().addingTimeInterval(Pin2Window.lifetime + 1)
    #expect(window.current(now: afterwards) == nil)
  }

  @Test
  internal func useDoesNotExtendTheWindow() {
    // The window belongs to the entry, not to the last signature: a
    // long batch asks again rather than stretching one authorization
    // across an afternoon.
    var window = Pin2Window()
    window.hold(Self.entry)
    let midway = Date().addingTimeInterval(Pin2Window.lifetime / 2)
    #expect(window.current(now: midway) == Self.entry)
    let afterwards = Date().addingTimeInterval(Pin2Window.lifetime + 1)
    #expect(window.current(now: afterwards) == nil)
  }

  @Test
  internal func forgettingIsImmediate() {
    var window = Pin2Window()
    window.hold(Self.entry)
    window.forget()
    #expect(window.current() == nil)
  }

  @Test
  internal func holdsNothingForAnEmptyEntry() {
    // A cancelled sheet reports an empty string; remembering it would
    // mean answering the next signature with nothing at all.
    var window = Pin2Window()
    window.hold(Self.entry)
    window.hold("")
    #expect(window.current() == nil)
  }
}
