// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation
import Security

/// Decides which token identities the module exposes.
///
/// The module installs under two names with disjoint profiles, and no
/// installed name exposes everything. The default name
/// (librefineid_pkcs11) serves authentication consumers -- ssh,
/// browser login -- and exposes only identities without the
/// contentCommitment (nonRepudiation) key usage; the qualified
/// signature key is legally weighty and must not be offered to every
/// PKCS#11-loading process or PIN-cached by an ssh-agent. The signing
/// name (librefineid_pkcs11_sign) serves document-signing
/// applications and exposes only the contentCommitment identities, so
/// a signing key picker cannot offer the wrong key.
internal enum IdentityPolicy {
  /// The contentCommitment (nonRepudiation) bit in the key-usage mask
  /// reported by SecCertificateCopyValues.
  private static let contentCommitmentBit = 2

  /// The marker in the loaded library's file name that selects the
  /// signing profile.
  private static let signingNameMarker = "_sign"

  /// Whether this copy of the module was loaded under the signing
  /// name.
  internal static let isSigningProfile: Bool = {
    var info = Dl_info()
    guard dladdr(#dsohandle, &info) != 0, let cName = info.dli_fname else {
      return false
    }
    let fileName = URL(fileURLWithPath: String(cString: cName)).lastPathComponent
    return fileName.contains(signingNameMarker)
  }()

  /// Whether the module exposes the identity behind this certificate.
  internal static func exposes(_ certificate: SecCertificate) -> Bool {
    let committing = keyUsage(certificate) & contentCommitmentBit != 0
    return isSigningProfile ? committing : !committing
  }

  /// The certificate's key-usage bitmask; zero when absent.
  private static func keyUsage(_ certificate: SecCertificate) -> Int {
    let wanted = [kSecOIDKeyUsage] as CFArray
    guard
      let values = SecCertificateCopyValues(certificate, wanted, nil)
        as? [String: [String: Any]],
      let usage = values[kSecOIDKeyUsage as String],
      let mask = usage[kSecPropertyKeyValue as String] as? Int
    else { return 0 }
    return mask
  }
}
