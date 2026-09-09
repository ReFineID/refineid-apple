// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Stable, collision-resistant names shared by every signing surface.
internal enum SignedDocumentName {
  nonisolated internal static func suggested(
    sourceNames: [String],
    format: SignatureFormat,
    at instant: Date = Date()
  ) -> String {
    let stem: String
    if sourceNames.count == 1, let name = sourceNames.first {
      stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
    } else {
      stem = String(
        localized: "output.multiple",
        defaultValue: "portfolio",
        table: "DocumentSigning")
    }
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime]
    let date = formatter.string(from: instant)
      .replacingOccurrences(of: ":", with: "-")
      .replacingOccurrences(of: "+00-00", with: "Z")
    let suffix = String(
      localized: "output.signed",
      defaultValue: "signed",
      table: "DocumentSigning")
    let pathExtension = format == .pades ? "pdf" : "asice"
    return "\(stem) - \(suffix) \(date).\(pathExtension)"
  }
}
