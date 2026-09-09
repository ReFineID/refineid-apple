// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Key-value storage abstraction for iCloud synchronization.
public protocol RappCloudStorage: Sendable {
  /// Reads data stored for the given key.
  func data(forKey defaultName: String) -> Data?
  /// Writes or clears data for the given key.
  func set(_ data: Data?, forKey defaultName: String)
  /// Synchronizes changes with underlying persistent storage.
  func synchronize() -> Bool
}
