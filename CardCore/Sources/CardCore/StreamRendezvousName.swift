// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation

/// The published name one side listens under and the other browses for.
///
/// The two devices meet by name, not by address: the card holder is the
/// only peer whose listener is reachable, and the requester finds it in
/// the name service and dials. The name is derived from something both
/// already share -- the scanned offer during pairing, the pairing's
/// rendezvous token after it -- so nothing new travels and the name says
/// nothing to anyone else.
public enum StreamRendezvousName {
  // MARK: Static Properties

  /// How much of the digest the name carries.
  ///
  /// Enough that two ceremonies on one network do not collide; short
  /// enough to stay well inside a service name's length limit.
  private static let digestPrefixByteCount = 8

  private static let prefix = "rf-"

  // MARK: Static Functions

  /// The name derived from a value both sides hold.
  ///
  /// A digest, never the value: an offer and a rendezvous token are each
  /// bearer material, and a published name is broadcast to the network.
  public static func name(sharing value: Data) -> String {
    let digest = SHA256.hash(data: value)
    let hex = digest.prefix(digestPrefixByteCount)
      .map { String(format: "%02x", $0) }
      .joined()
    return prefix + hex
  }

  /// The name derived from a scanned offer.
  public static func name(sharingOfferURI uri: String) -> String {
    name(sharing: Data(uri.utf8))
  }
}
