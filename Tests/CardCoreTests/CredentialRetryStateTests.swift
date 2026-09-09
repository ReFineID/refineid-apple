// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct CredentialRetryStateTests {
  @Test
  internal func preservesEachCredentialReading() throws {
    let state = try CredentialRetryState(
      pin1: count(RetryCount.pristineAllowance),
      pin2: count(RetryCount.pristineAllowance - 1),
      puk: count(RetryCount.pristineAllowance - 2)
    )
    #expect(state.pin1.attemptsRemaining == RetryCount.pristineAllowance)
    #expect(state.pin2.attemptsRemaining == RetryCount.pristineAllowance - 1)
    #expect(state.puk.attemptsRemaining == RetryCount.pristineAllowance - 2)
  }

  private func count(_ value: UInt8) throws -> RetryCount {
    try #require(RetryCount(attemptsRemaining: value))
  }
}
