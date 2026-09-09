// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// The first frame a dialer sends, which carries no protocol meaning.
///
/// The transport needs a dialer to say something before the listener knows a
/// peer arrived, and the protocol above needs the requester to speak first.
/// This is what fills that gap: the listener reads it as the arrival itself
/// and never hands it upward, so the first frame the session sees is still
/// the one the requester sent.
public enum StreamRelayPreamble {
  /// The single byte a dialer announces itself with.
  ///
  /// Its value carries no meaning: the transport needs one byte and the
  /// protocol above needs it not to be a message.
  private static let helloByte: UInt8 = 1

  /// What a dialer sends to announce itself.
  public static let hello = Data([helloByte])
}
