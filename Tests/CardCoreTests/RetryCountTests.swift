// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct RetryCountTests {
  @Test
  internal func refusesImplausibleValues() {
    #expect(RetryCount(attemptsRemaining: RetryCount.maximumPlausible + 1) == nil)
    #expect(RetryCount(attemptsRemaining: .max) == nil)
  }

  @Test
  internal func acceptsWholePlausibleRange() {
    for value in 0...RetryCount.maximumPlausible {
      #expect(RetryCount(attemptsRemaining: value) != nil)
    }
  }

  @Test
  internal func pristineAllowanceIsPristine() throws {
    let count = try #require(
      RetryCount(attemptsRemaining: RetryCount.pristineAllowance)
    )
    #expect(count.isPristine)
    #expect(!count.isBlocked)
  }

  @Test
  internal func zeroIsBlockedNotPristine() throws {
    let count = try #require(RetryCount(attemptsRemaining: 0))
    #expect(count.isBlocked)
    #expect(!count.isPristine)
  }
}
