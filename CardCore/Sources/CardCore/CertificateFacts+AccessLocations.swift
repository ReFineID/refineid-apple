// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// X.509 access-location parsing used by `CertificateFacts`.
extension CertificateFacts {
  /// HTTP-family URIs in CRL distribution-point full names.
  internal static func distributionPointUrls(
    in value: DerReader.Element,
    der: Data
  ) -> [String] {
    var wrapped = DerReader(der, within: value)
    guard
      let points = wrapped.next(),
      points.tag == DerValues.tagSequence,
      wrapped.isAtEnd
    else { return [] }
    var urls: [String] = []
    var list = DerReader(der, within: points)
    while let point = list.next() {
      guard point.tag == DerValues.tagSequence else { continue }
      var fields = DerReader(der, within: point)
      guard
        let distributionPoint = fields.next(),
        distributionPoint.tag == DerValues.tagContext0Constructed
      else { continue }
      var named = DerReader(der, within: distributionPoint)
      guard
        let fullName = named.next(),
        fullName.tag == DerValues.tagContext0Constructed,
        named.isAtEnd
      else { continue }
      var names = DerReader(der, within: fullName)
      while let name = names.next() {
        guard
          name.tag == DerValues.tagContext6Primitive,
          let address = String(
            bytes: names.contentData(of: name), encoding: .ascii
          ),
          let url = URL(string: address),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host != nil
        else { continue }
        urls.append(address)
      }
    }
    var seen: Set<String> = []
    return urls.filter { seen.insert($0).inserted }
  }

  /// The URLs inside one access extension, by method.
  internal static func urls(
    in value: DerReader.Element,
    der: Data
  ) -> (issuers: [String], ocsp: [String]) {
    var issuers: [String] = []
    var responders: [String] = []
    var valueReader = DerReader(der, within: value)
    guard let descriptions = valueReader.next() else {
      return ([], [])
    }
    var list = DerReader(der, within: descriptions)
    while let description = list.next() {
      var parts = DerReader(der, within: description)
      guard
        let method = parts.next(),
        let location = parts.next(),
        location.tag == DerValues.tagContext6Primitive,
        let url = String(
          bytes: parts.contentData(of: location), encoding: .ascii
        )
      else {
        continue
      }
      let methodOid = parts.data(of: method)
      if methodOid == DerEncoder.objectIdentifier(SignOids.caIssuers) {
        issuers.append(url)
      } else if methodOid == DerEncoder.objectIdentifier(SignOids.ocsp) {
        responders.append(url)
      }
    }
    return (issuers, responders)
  }
}
