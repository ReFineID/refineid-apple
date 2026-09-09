// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS) && REFINEID_LOCAL_CARD
  import CardCore
  import Foundation
  import RappEngine

  /// The selected pair's rendezvous facts the holder listens under.
  ///
  /// The holder is the side whose listener the network lets everyone
  /// reach, so it publishes and the requester dials. Both derive the same
  /// name from the pairing's rendezvous token, and the requester's opening
  /// frame is the session preamble built from that token -- the arrival
  /// that says which pairing the dial is for.
  internal struct PhoneStreamPairContext {
    /// The name this pair's listener publishes.
    internal let serviceName: String

    /// The opening frame a requester of this pair dials with.
    internal let sessionPreamble: Data

    /// The stream endpoints to dial, if this pair was established over explicit stream endpoints.
    internal let streamEndpoints: [String]

    /// The underlying pair record.
    internal let pairRecord: RappPairRecord

    /// Resolves the listening facts for the selected pair; nil when no
    /// pair is selected or the pair cannot be loaded.
    internal static func resolve(vault: RappDeviceVault) -> Self? {
      guard let pair = try? PhoneProxyPairSelection.resolveSelectedPair(vault: vault)
      else { return nil }
      let metadata = pair.metadata()
      guard
        let preamble = try? rappStreamSessionPreamble(
          rendezvousToken: metadata.rendezvousToken
        )
      else { return nil }
      return Self(
        serviceName: StreamRendezvousName.name(sharing: metadata.rendezvousToken),
        sessionPreamble: preamble,
        streamEndpoints: metadata.streamEndpoints ?? [],
        pairRecord: pair
      )
    }

    /// Resolves the listening facts for all active pairs.
    internal static func resolveAll(vault: RappDeviceVault) -> [Self] {
      guard let activeIDs = try? vault.activePairIDs(), !activeIDs.isEmpty else { return [] }
      var results: [Self] = []
      var seenServices = Set<String>()
      for pairID in activeIDs {
        guard let pair = try? RappPairRecord.loadFromVault(pairId: pairID, vault: vault) else {
          continue
        }
        let metadata = pair.metadata()
        guard
          let preamble = try? rappStreamSessionPreamble(
            rendezvousToken: metadata.rendezvousToken
          )
        else { continue }
        let service = StreamRendezvousName.name(sharing: metadata.rendezvousToken)
        if seenServices.insert(service).inserted {
          results.append(
            Self(
              serviceName: service,
              sessionPreamble: preamble,
              streamEndpoints: metadata.streamEndpoints ?? [],
              pairRecord: pair
            )
          )
        }
      }
      return results
    }
  }
#endif
