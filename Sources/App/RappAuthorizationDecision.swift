// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)
  internal enum RappAuthorizationDecision: Sendable, Equatable {
    case approved
    case approvedBrowserAuthentication(pin1: String)
    case approvedDocumentSignature(pin2: String)
    case denied
  }
#endif
