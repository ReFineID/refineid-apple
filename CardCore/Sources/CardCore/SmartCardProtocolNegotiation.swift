// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(CryptoTokenKit)

  import CryptoTokenKit
  import Foundation

  /// Protocol offers for readers whose CCID firmware cannot negotiate a
  /// multi-protocol connection reliably.
  ///
  /// The ordinary offer remains first. A field-observed no-name
  /// `Generic EMV Smartcard Reader` reports a contact card unresponsive
  /// when offered every protocol together, but opens it when offered
  /// T=0 alone. Retrying one protocol at a time matches the resilient
  /// PC/SC transport without weakening removal, contention, or timeout
  /// failures into retries.
  public enum SmartCardProtocolNegotiation {
    /// Offers for this interface, in negotiation order.
    ///
    /// Contactless slots have a bounded field and already negotiate as
    /// T=1; spending that field on desktop-reader fallbacks would make a
    /// real transport failure slower. Contact readers get the ordinary
    /// offer followed by the two ISO character protocols separately.
    public static func offers(answerToReset: Data?) -> [TKSmartCardProtocol] {
      guard
        let answerToReset,
        !AnswerToReset.indicatesContactlessInterface(bytes: answerToReset)
      else {
        return [.any]
      }
      return [.any, .t0, .t1]
    }

    /// Whether a refused session is the negotiation failure for which a
    /// narrower protocol offer is safe.
    public static func retries(after failure: (any Error)?) -> Bool {
      guard let failure else { return false }
      let error = failure as NSError
      return error.domain == TKErrorDomain
        && error.code == TKError.Code.communicationError.rawValue
    }
  }

#endif
