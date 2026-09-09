// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The transports a holder currently allows, guaranteed never empty.
///
/// The mistake this type makes impossible is a selection that permits
/// nothing: a card app that has disabled every way of reaching a card
/// cannot report a useful status, and the failure would surface far from
/// the settings screen that caused it. `Documentation/typing-discipline.md`
/// names the contact/contactless transport distinction as one worth
/// lifting into the type system for exactly this reason.
public struct CardTransportSelection: Equatable, Sendable {
  /// Every transport the build knows about.
  public static let all = Self(unchecked: Set(CardTransport.allCases))

  /// Contact readers only: the whole of macOS, and the fallback
  /// anywhere the phone has no antenna.
  public static let readerOnly = Self(unchecked: [.reader])

  /// The permitted transports.
  ///
  /// Never empty.
  public let enabled: Set<CardTransport>

  /// Refuses an empty selection.
  public init?(enabled: Set<CardTransport>) {
    guard !enabled.isEmpty else { return nil }
    self.enabled = enabled
  }

  /// Trusted construction for the static members above, whose literals
  /// are non-empty by inspection.
  private init(unchecked enabled: Set<CardTransport>) {
    self.enabled = enabled
  }

  /// Whether the holder allows this transport.
  public func permits(_ transport: CardTransport) -> Bool {
    enabled.contains(transport)
  }

  /// The selection with `transport` allowed as well.
  public func enabling(_ transport: CardTransport) -> Self {
    Self(unchecked: enabled.union([transport]))
  }

  /// The selection with `transport` disallowed.
  ///
  /// Returns nil when that would leave nothing enabled; a caller that
  /// gets nil should keep the current selection and tell the holder why.
  public func disabling(_ transport: CardTransport) -> Self? {
    Self(enabled: enabled.subtracting([transport]))
  }

  /// This selection narrowed to what the running platform actually has.
  ///
  /// A preference written on an iPhone can name the phone antenna and
  /// then be read on a Mac, which has none. Clamping keeps such a value
  /// from leaving the Mac with nothing enabled; if the intersection is
  /// empty the supported set itself is the answer.
  public func clamped(to supported: Self) -> Self {
    Self(enabled: enabled.intersection(supported.enabled)) ?? supported
  }
}
