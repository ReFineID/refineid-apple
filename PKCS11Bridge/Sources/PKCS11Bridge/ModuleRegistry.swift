// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import LocalAuthentication
import Security
import Synchronization

/// Mutable module state shared by every PKCS#11 entry point.
///
/// All access goes through `ModuleRegistry.shared.withLock`; the
/// `@unchecked Sendable` conformance is sound because the mutex is the
/// only route to an instance and the stored Security references are
/// never handed out without it.
internal struct ModuleRegistry: @unchecked Sendable {
  /// The cryptosystem a token identity uses, which decides its
  /// mechanism, its attributes, and how its signature is encoded.
  internal enum KeyKind {
    case elliptic
    case rsa
  }

  /// One PKCS#11 object backed by a keychain token item.
  internal struct ObjectRecord {
    /// The object's handle, stable across snapshot refreshes.
    internal let handle: CK_OBJECT_HANDLE

    /// CKO_CERTIFICATE, CKO_PUBLIC_KEY, or CKO_PRIVATE_KEY.
    internal let objectClass: CK_OBJECT_CLASS

    /// Attribute values served by C_GetAttributeValue and matched by
    /// C_FindObjects, fully precomputed at snapshot time.
    internal let attributes: [CK_ATTRIBUTE_TYPE: Data]

    /// The identity's cryptosystem.
    internal let keyKind: KeyKind

    /// EC field width in bytes; zero on RSA and certificate objects.
    internal let fieldWidth: Int

    /// The signature this key produces, in bytes.
    ///
    /// Both halves of an EC signature, or one modulus for RSA. Zero
    /// on certificate objects.
    internal let signatureLength: Int

    /// The signing key, present on private-key objects only.
    internal let privateKey: SecKey?
  }

  /// One CryptoTokenKit token mapped to a PKCS#11 slot.
  internal struct TokenRecord {
    /// The slot serving this token, stable across refreshes.
    internal let slotID: CK_SLOT_ID

    /// The CryptoTokenKit token instance identifier.
    internal let tokenID: String

    /// Human-readable token name shown in CK_TOKEN_INFO.
    internal let label: String

    /// The token's objects: per identity a certificate, a public key,
    /// and a private key sharing one CKA_ID.
    internal var objects: [ObjectRecord]

    /// Whether C_Login succeeded on this token.
    internal var loggedIn = false

    /// Carries a PIN supplied through C_Login to key operations.
    internal var authenticationContext: LAContext?
  }

  /// One open session.
  internal struct SessionRecord {
    /// The slot this session is bound to.
    internal let slotID: CK_SLOT_ID

    /// The CKF_* flags the session was opened with.
    internal let flags: CK_FLAGS

    /// Whether a find operation is active.
    internal var findActive = false

    /// Result handles of the active find operation.
    internal var findResults: [CK_OBJECT_HANDLE] = []

    /// Position of the next C_FindObjects result.
    internal var findIndex = 0

    /// The key of the active signing operation, nil when none.
    internal var signKey: SecKey?

    /// The cryptosystem of the active signing operation.
    internal var signKind = KeyKind.elliptic

    /// EC field width in bytes for the active signing operation.
    internal var signWidth = 0

    /// Signature length in bytes for the active signing operation.
    internal var signatureLength = 0
  }

  /// The single registry instance, guarded by its lock.
  internal static let shared = Mutex(Self())

  /// Tokens currently present, one slot each.
  internal var tokens: [TokenRecord] = []

  /// Open sessions by handle.
  internal var sessions: [CK_SESSION_HANDLE: SessionRecord] = [:]

  /// Stable slot numbering across refreshes, keyed by token ID.
  internal var slotNumbers: [String: CK_SLOT_ID] = [:]

  /// Stable object numbering across refreshes, keyed by token ID,
  /// object class, and CKA_ID.
  internal var objectNumbers: [String: CK_OBJECT_HANDLE] = [:]

  /// Next slot number to assign.
  internal var nextSlotID: CK_SLOT_ID = 0

  /// Next session handle to assign; zero is CK_INVALID_HANDLE.
  internal var nextSessionHandle: CK_SESSION_HANDLE = 1

  /// Next object handle to assign; zero is CK_INVALID_HANDLE.
  internal var nextObjectHandle: CK_OBJECT_HANDLE = 1

  /// Returns the token serving the given slot, if present.
  internal func token(slotID: CK_SLOT_ID) -> TokenRecord? {
    tokens.first { $0.slotID == slotID }
  }

  /// Mutates the token serving the given slot, if present.
  internal mutating func withToken(
    slotID: CK_SLOT_ID, _ body: (inout TokenRecord) -> CK_RV
  ) -> CK_RV {
    guard let index = tokens.firstIndex(where: { $0.slotID == slotID }) else {
      return CKR_TOKEN_NOT_PRESENT
    }
    return body(&tokens[index])
  }

  /// Returns the object with the given handle, searching all tokens.
  internal func object(handle: CK_OBJECT_HANDLE) -> ObjectRecord? {
    for token in tokens {
      if let found = token.objects.first(where: { $0.handle == handle }) {
        return found
      }
    }
    return nil
  }
}
