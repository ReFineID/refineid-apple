// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Production iCloud Key-Value store implementation with local defaults fallback.
public final class UbiquitousKeyValueStoreCloudStorage: RappCloudStorage, @unchecked Sendable {
  private let store: NSUbiquitousKeyValueStore
  private let defaults: UserDefaults

  /// Creates a cloud storage instance backed by NSUbiquitousKeyValueStore and UserDefaults.
  public init(
    store: NSUbiquitousKeyValueStore = .default,
    defaults: UserDefaults = .standard
  ) {
    self.store = store
    self.defaults = defaults
  }

  /// Reads binary data from the iCloud key-value store, falling back to local defaults.
  public func data(forKey defaultName: String) -> Data? {
    if let cloudData = store.data(forKey: defaultName) {
      return cloudData
    }
    return defaults.data(forKey: defaultName)
  }

  /// Sets or removes binary data in both iCloud and local defaults.
  public func set(_ data: Data?, forKey defaultName: String) {
    if let data {
      store.set(data, forKey: defaultName)
      defaults.set(data, forKey: defaultName)
    } else {
      store.removeObject(forKey: defaultName)
      defaults.removeObject(forKey: defaultName)
    }
  }

  /// Forces in-memory changes to synchronize with disk/iCloud daemon.
  public func synchronize() -> Bool {
    defaults.synchronize()
    return store.synchronize()
  }
}
