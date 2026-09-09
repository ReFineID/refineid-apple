// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import CardCore

/// Collects what one side of a stream channel reported.
internal actor StreamRelayMailbox {
  private var frames: [Data] = []
  private var names: [String] = []

  /// The first frame that arrived, if one has.
  internal var firstFrame: Data? { frames.first }

  /// What this side reported, in order, for a failure to name.
  internal var reported: String { names.isEmpty ? "nothing" : names.joined(separator: ", ") }

  /// Records one event, keeping the frames.
  internal func record(_ event: StreamRelayEvent) {
    switch event {
    case .connected:
      names.append("connected")

    case .frame(let payload):
      names.append("frame(\(payload.count))")
      frames.append(payload)

    case .closed(let error):
      names.append("closed(\(String(describing: error)))")
    }
  }
}
