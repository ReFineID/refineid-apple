// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// A command that durable state has already accounted for.
///
/// The wrapper cannot be copied and executing it consumes the value, so the
/// type itself prevents a second transmission.
internal struct PendingCardCommand<Command>: ~Copyable {
  private let command: Command

  internal init(command: Command) {
    self.command = command
  }

  /// Hands the one command to the card and consumes the wrapper.
  internal consuming func execute<Answer>(_ transmitOnce: (Command) -> Answer) -> Answer {
    transmitOnce(command)
  }
}
