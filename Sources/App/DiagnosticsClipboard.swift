// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Puts a diagnostics capture on the pasteboard, whichever pasteboard the
/// platform has.
///
/// A share sheet is the right way to send a trace to somebody else; the
/// pasteboard is the right way to get it into the text field, terminal or
/// note that is already open. Both exist because a capture that is
/// awkward to move is a capture nobody takes.
internal enum DiagnosticsClipboard {
  /// Replaces the pasteboard contents with `text`.
  ///
  /// Main-actor bound because both platform pasteboards are; the only
  /// caller is a button, which is already there.
  @MainActor
  internal static func copy(_ text: String) {
    #if os(iOS)
      UIPasteboard.general.string = text
    #else
      NSPasteboard.general.clearContents()
      _ = NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}
