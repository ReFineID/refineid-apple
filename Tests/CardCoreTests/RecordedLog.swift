// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A lock-protected append-only record usable from transport callbacks.
internal final class RecordedLog<Element>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: [Element] = []

  /// A snapshot of everything recorded so far, in order.
  internal var values: [Element] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  /// Appends one element and returns the new count.
  @discardableResult
  internal func append(_ element: Element) -> Int {
    lock.lock()
    defer { lock.unlock() }
    storage.append(element)
    return storage.count
  }
}
