// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

#if os(macOS)
  import AppKit
#endif

/// The public site for this product, in the one place the About box
/// and any other surface that names it can share.
internal enum ProductSite {
  /// Shown as the link, and used as the host of ``url``.
  internal static let label = "www.refineid.fi"

  /// The copyright line the About box shows above the site.
  internal static let copyright = "Copyright 2026 Petri Koistinen"

  private static let scheme = "https"
  private static let path = "/"

  /// The address the About box opens.
  internal static let url: URL = {
    var components = URLComponents()
    components.scheme = scheme
    components.host = label
    components.path = path
    guard let address = components.url else {
      preconditionFailure("ProductSite URL components are statically valid")
    }
    return address
  }()

  #if os(macOS)
    /// Centered, clickable site name for the credits slot under all
    /// other About content.
    private static var credits: NSAttributedString {
      let style = NSMutableParagraphStyle()
      style.alignment = .center
      return NSAttributedString(
        string: label,
        attributes: [
          .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
          .foregroundColor: NSColor.linkColor,
          .link: url,
          .paragraphStyle: style,
          .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
      )
    }

    /// The standard About panel, with the site under the version and
    /// copyright the panel already draws.
    @MainActor
    internal static func presentAboutPanel() {
      NSApp.orderFrontStandardAboutPanel(options: [
        .credits: credits
      ])
    }
  #endif
}
