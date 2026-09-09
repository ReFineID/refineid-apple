// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// In-memory storage implementation for deterministic testing.
public final class InMemoryCloudStorage: RappCloudStorage, @unchecked Sendable {
  private var storage: [String: Data] = [:]
  private let lock = NSLock()

  /// Creates an in-memory cloud storage instance with optional preloaded data.
  public init(initialData: [String: Data] = [:]) {
    self.storage = initialData
  }

  /// Reads binary data from in-memory dictionary.
  public func data(forKey defaultName: String) -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return storage[defaultName]
  }

  /// Sets or removes binary data in in-memory dictionary.
  public func set(_ data: Data?, forKey defaultName: String) {
    lock.lock()
    defer { lock.unlock() }
    if let data {
      storage[defaultName] = data
    } else {
      storage.removeValue(forKey: defaultName)
    }
  }

  /// Simulates synchronization.
  public func synchronize() -> Bool {
    true
  }

  /// Dumps all stored keys and values for test inspection.
  public func dump() -> [String: Data] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}
