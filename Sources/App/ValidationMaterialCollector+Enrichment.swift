// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CardCore
import Foundation

/// Best-effort parent material above an already authenticated anchor.
extension ValidationMaterialCollector {
  /// Adds available parent certificates and status without changing the
  /// strict trust result already established below `anchor`.
  internal static func enrichAboveAnchor(
    _ anchor: Data,
    at referenceDate: Date,
    evidenceTime: Date,
    collection: inout Collection,
    dependencies: Dependencies
  ) async {
    var current = anchor
    var visited: Set<Data> = []
    for _ in 0..<Self.maximumDepth {
      guard
        visited.insert(current).inserted,
        let facts = CertificateFacts(der: current),
        let parent = try? await Self.issuer(
          of: current,
          facts: facts,
          at: referenceDate,
          collection: &collection,
          dependencies: dependencies
        )
      else { return }
      collection.addCertificate(parent)
      if !collection.checked.contains(current),
        let evidence = try? await Self.status(
          of: current,
          facts: facts,
          under: parent,
          at: evidenceTime,
          dependencies: dependencies
        )
      {
        collection.checked.insert(current)
        Self.add(evidence, to: &collection)
      }
      current = parent
    }
  }

  /// Adds one authenticated best-effort status object.
  private static func add(
    _ evidence: StatusEvidence,
    to collection: inout Collection
  ) {
    switch evidence {
    case .ocsp(let response):
      collection.addOcsp(response)

    case .revocationList(let list):
      collection.addRevocationList(list)
    }
  }
}
