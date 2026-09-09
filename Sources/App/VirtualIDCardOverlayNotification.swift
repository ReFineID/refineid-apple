// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import Foundation

  /// Posted when the virtual ID card editor is dismissed.
  internal enum VirtualIDCardOverlayNotification {
    internal static let editorDidDismiss = Notification.Name(
      "fi.refineid.virtual-id-card-editor-did-dismiss")
  }

#endif
