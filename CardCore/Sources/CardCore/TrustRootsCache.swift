// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CryptoKit
import Foundation
import Security

/// Dynamic in-memory cache and accessors for FINEID root and intermediate CA certificates.
///
/// Rather than bundling static CA certificate files in the application, certificates
/// are fetched directly from the smart card (`EF.4334` for Root CA, `EF.4336` for
/// Intermediate CA) or received over the RAPP protocol when an application starts.
///
/// Thread safety is ensured via an internal `NSLock`.
public final class TrustRootsCache: @unchecked Sendable {
  /// Shared global instance.
  public static let shared = TrustRootsCache()

  /// Well-known pinned DVV Gov. Root CA - G3 RSA SHA-256 fingerprint.
  public static let pinnedDvvG3RsaSha256: [UInt8] = FineidValues.pinnedDvvG3RsaSha256

  /// Well-known pinned DVV Gov. Root CA - G3 ECC SHA-256 fingerprint.
  public static let pinnedDvvG3EccSha256: [UInt8] = FineidValues.pinnedDvvG3EccSha256

  private let lock = NSLock()
  private var rootCaDER: Data?
  private var intermediateCaDER: Data?
  private var extraCasDER: [Data] = []
  private var certsBySubject: [Data: Data] = [:]
  private var certsByFingerprint: [Data: Data] = [:]

  /// Returns the cached intermediate CA in DER format, if available.
  public var intermediateCertificate: Data? {
    lock.lock()
    defer { lock.unlock() }
    return intermediateCaDER
  }

  /// Returns the cached root CA in DER format, if available.
  public var rootCertificate: Data? {
    lock.lock()
    defer { lock.unlock() }
    return rootCaDER
  }

  /// Returns all cached certificates.
  public var allCertificates: [Data] {
    lock.lock()
    defer { lock.unlock() }
    var list: [Data] = []
    if let root = rootCaDER { list.append(root) }
    if let inter = intermediateCaDER { list.append(inter) }
    list.append(contentsOf: extraCasDER)
    return list
  }

  /// Creates a new, empty in-memory trust roots cache.
  public init() {
    // In-memory cache is initialized empty.
  }

  /// Registers an on-card issuing intermediate CA certificate.
  public func register(_ certificateDER: Data) {
    lock.lock()
    defer { lock.unlock() }
    intermediateCaDER = certificateDER
    indexCertificate(certificateDER)
  }

  /// Registers an on-card root CA certificate.
  public func registerRoot(_ certificateDER: Data) {
    lock.lock()
    defer { lock.unlock() }
    rootCaDER = certificateDER
    indexCertificate(certificateDER)
  }

  /// Registers an extra CA certificate.
  public func registerExtra(_ certificateDER: Data) {
    lock.lock()
    defer { lock.unlock() }
    extraCasDER.append(certificateDER)
    indexCertificate(certificateDER)
  }

  /// Returns the matching cached intermediate/root certificate for a given leaf.
  public func der(matching leafDER: Data) -> Data? {
    guard
      let leaf = SecCertificateCreateWithData(nil, leafDER as CFData),
      let issuer = SecCertificateCopyNormalizedIssuerSequence(leaf) as Data?
    else {
      return nil
    }

    lock.lock()
    defer { lock.unlock() }

    if let direct = certsBySubject[issuer] {
      return direct
    }

    for candidate in allCertificates {
      guard
        let cert = SecCertificateCreateWithData(nil, candidate as CFData),
        let subject = SecCertificateCopyNormalizedSubjectSequence(cert) as Data?
      else {
        continue
      }
      if subject == issuer {
        certsBySubject[issuer] = candidate
        return candidate
      }
    }
    return nil
  }

  /// Checks whether a SHA-256 fingerprint matches any cached CA certificate.
  public func containsFingerprint(_ fingerprint: Data) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return certsByFingerprint[fingerprint] != nil
  }

  /// Checks whether a SHA-256 fingerprint matches a trusted root CA.
  public func isTrustedRoot(fingerprint: Data) -> Bool {
    if containsFingerprint(fingerprint) {
      return true
    }
    let rsa = Data(Self.pinnedDvvG3RsaSha256)
    let ecc = Data(Self.pinnedDvvG3EccSha256)
    return fingerprint == rsa || fingerprint == ecc
  }

  /// Resets the cache (primarily for tests).
  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    rootCaDER = nil
    intermediateCaDER = nil
    extraCasDER.removeAll()
    certsBySubject.removeAll()
    certsByFingerprint.removeAll()
  }

  /// Indexes a certificate by its normalized subject sequence and SHA-256 fingerprint.
  private func indexCertificate(_ der: Data) {
    let fingerprint = Data(SHA256.hash(data: der))
    certsByFingerprint[fingerprint] = der

    guard
      let cert = SecCertificateCreateWithData(nil, der as CFData),
      let subject = SecCertificateCopyNormalizedSubjectSequence(cert) as Data?
    else {
      return
    }
    certsBySubject[subject] = der
  }
}
