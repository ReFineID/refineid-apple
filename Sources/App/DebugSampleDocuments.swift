// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if DEBUG && os(macOS)

  import Foundation

  /// Development-only seeding of the pile of documents to sign.
  ///
  /// The pile is built by dropping files, which comes from another
  /// process and is not something an automated audit can perform. The
  /// rows, their removals and what they say they will become would
  /// therefore be the one part of the window no audit ever reached.
  /// This puts placeholder files in the pile at launch so it is
  /// audited like every other screen.
  ///
  /// The files are real and written to this process's temporary
  /// directory, because the rows show the icon the system gives a file
  /// and a name that resolves to nothing is not what a holder sees.
  /// Release builds contain none of this type or its argument.
  internal enum DebugSampleDocuments {
    /// A normal-UI launch argument; it is deliberately not a debug
    /// launch mode.
    internal static let launchArgument = "--seed-document-pile"
    internal static let seedDocumentArgument = "--seed-document"

    /// The placeholder names, chosen to be several file types: a mixed
    /// pile is the one that can only take the container shape.
    private static let names = [
      "Agreement.pdf", "Annex one.odt", "Figures.png", "Schedule.csv",
    ]

    /// Answers documents explicitly seeded via one or more launch arguments.
    internal static func targetDocuments() -> [URL] {
      let args = ProcessInfo.processInfo.arguments
      var urls: [URL] = []
      for (index, arg) in args.enumerated()
      where arg == seedDocumentArgument && index + 1 < args.count {
        let raw = args[index + 1]
        let expanded = raw.hasPrefix("~/") ? NSHomeDirectory() + raw.dropFirst() : raw
        urls.append(URL(fileURLWithPath: expanded))
      }
      return urls
    }

    /// Answers a single document explicitly seeded via launch argument.
    internal static func targetDocument() -> URL? {
      targetDocuments().first
    }

    /// Whether this process was explicitly launched to seed the pile.
    internal static func isEnabled() -> Bool {
      Self.isEnabled(arguments: ProcessInfo.processInfo.arguments)
    }

    /// Whether the supplied process arguments explicitly seed the pile.
    internal static func isEnabled(arguments: [String]) -> Bool {
      arguments.contains(Self.launchArgument)
        && !DebugLaunchMode.allCases.contains { mode in
          arguments.contains(mode.rawValue)
        }
    }

    /// Writes the placeholders and answers where they are.
    ///
    /// A file that could not be written is left out rather than
    /// returned as a path to nothing, so what the pile shows is always
    /// a file that exists.
    internal static func seeded() -> [URL] {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("refineid-sample-documents")
      try? FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true
      )
      return Self.names.compactMap { name in
        let file = directory.appendingPathComponent(name)
        guard (try? Data("placeholder".utf8).write(to: file)) != nil else {
          return nil
        }
        return file
      }
    }
  }

#endif
