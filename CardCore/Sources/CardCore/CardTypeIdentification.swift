// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// What a card is, as far as an answer to reset can say.
public struct CardTypeIdentification: Equatable, Sendable {
  /// How confidently the card was named.
  public enum Confidence: Equatable, Sendable {
    /// The historical bytes match a card DVV documents.
    case documented

    /// Only the platform generation matched, so the exact card is not
    /// one the table knows.
    case generationOnly
  }

  /// The name to show: a documented card, or a generation.
  public let name: String

  /// Which of the two the name is.
  public let confidence: Confidence

  /// Names the card behind `answerToReset`, or nil when nothing matches.
  ///
  /// Nil rather than a nearest guess. The whole reason this exists as a
  /// table with dates on it is that a card can be newer than the
  /// document: rounding an unknown card to the closest row would state a
  /// model number that nobody has verified, on a screen whose purpose is
  /// to say what is actually in the reader.
  public static func identify(answerToReset: Data) -> Self? {
    guard let parsed = AnswerToReset(bytes: answerToReset) else { return nil }
    let historical = parsed.historicalBytes
    if let exact = FineidCardTypeValues.exact.first(where: { candidate in
      candidate.historicalBytes == historical
    }) {
      return Self(name: exact.name, confidence: .documented)
    }
    guard
      let family = FineidCardTypeValues.families.first(where: { candidate in
        historical.starts(with: candidate.historicalPrefix)
      })
    else {
      return nil
    }
    return Self(name: family.name, confidence: .generationOnly)
  }
}
