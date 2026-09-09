// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The closed command handed to the card after the durable commit.
///
/// It carries no card access number, no PIN, and no raw APDU. The authorizer
/// holds those locally and the platform adapter maps this semantic operation
/// onto the reviewed card protocol.
internal struct AuthorizedCardCommand: Equatable {
  internal let operation: CardOperation
}
