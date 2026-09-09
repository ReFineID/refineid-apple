// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Testing

@Suite
internal struct AcceptedPin1MemoryTests {
  private func serial(_ value: String) -> TokenSerial {
    guard let serial = TokenSerial(value: value) else {
      fatalError("test serial must be valid")
    }
    return serial
  }

  private func pin(_ digits: String) -> Pin1 {
    guard let pin = Pin1(digits: digits) else {
      fatalError("test PIN must be valid")
    }
    return pin
  }

  private func fingerprint(_ digits: String, _ serial: TokenSerial) -> PinFingerprint {
    pin(digits).fingerprint(boundTo: serial)
  }

  /// True when the optional carried a PIN (consuming it either way).
  private func present(_ candidate: consuming Pin1?) -> Bool {
    if let value = candidate {
      _ = value
      return true
    }
    return false
  }

  @Test
  internal func storeThenCheckoutReturnsTheSameDigits() {
    let memory = AcceptedPin1Memory()
    let card = serial("AABBCC01")
    memory.store(pin("123456"), serial: card)
    guard let reused = memory.checkout(serial: card) else {
      Issue.record("expected an accepted PIN1")
      return
    }
    let reusedFingerprint = reused.fingerprint(boundTo: card)
    #expect(reusedFingerprint == fingerprint("123456", card))
  }

  @Test
  internal func checkoutRefusesADifferentCard() {
    let memory = AcceptedPin1Memory()
    memory.store(pin("123456"), serial: serial("CARD-A"))
    let wrongCard = present(memory.checkout(serial: serial("CARD-B")))
    #expect(!wrongCard)
  }

  @Test
  internal func keepsIndependentEntriesForDifferentCards() {
    let memory = AcceptedPin1Memory()
    let first = serial("AABBCC02")
    let second = serial("AABBCC03")
    memory.store(pin("123456"), serial: first)
    memory.store(pin("654321"), serial: second)

    guard
      let firstPin = memory.checkout(serial: first),
      let secondPin = memory.checkout(serial: second)
    else {
      Issue.record("expected both accepted PIN1 values")
      return
    }
    #expect(firstPin.fingerprint(boundTo: first) == fingerprint("123456", first))
    #expect(secondPin.fingerprint(boundTo: second) == fingerprint("654321", second))
  }

  @Test
  internal func clearDropsOnlyTheNamedCard() {
    let memory = AcceptedPin1Memory()
    let card = serial("AABBCC04")
    let other = serial("AABBCC05")
    memory.store(pin("123456"), serial: card)
    memory.store(pin("654321"), serial: other)
    memory.clear(serial: card)
    let afterClear = present(memory.checkout(serial: card))
    let otherRemains = present(memory.checkout(serial: other))
    #expect(!afterClear)
    #expect(otherRemains)
  }

  @Test
  internal func clearAllDropsEveryCard() {
    let memory = AcceptedPin1Memory()
    let first = serial("AABBCC06")
    let second = serial("AABBCC07")
    memory.store(pin("123456"), serial: first)
    memory.store(pin("654321"), serial: second)
    memory.clearAll()
    let firstMissing = present(memory.checkout(serial: first))
    let secondMissing = present(memory.checkout(serial: second))
    #expect(!firstMissing)
    #expect(!secondMissing)
  }
}
