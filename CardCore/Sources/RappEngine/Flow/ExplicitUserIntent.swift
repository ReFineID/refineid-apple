// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// Evidence that a local user explicitly started this session.
///
/// The protocol never reconnects on its own, so the requester side cannot be
/// entered without one of these.
internal struct ExplicitUserIntent: Equatable {}
