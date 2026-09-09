// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation
import Security

/// Signing entry points (spec section 5.13): single-part CKM_ECDSA over
/// SecKeyCreateSignature.
///
/// The mechanism input is the caller's digest and the output is raw
/// r||s, so the X9.62 DER that Security.framework produces is converted
/// by EcEncoding. The actual card work and PIN prompting happen in the
/// system token daemon; the signature call runs outside the registry
/// lock because it can block on the PIN dialog.
internal enum SignEntryPoints {
  /// The result of signing one digest: the raw signature, or the
  /// Cryptoki code describing why there is none.
  private enum SignOutcome {
    case failed(CK_RV)
    case signed(Data)
  }

  /// The signing operation a session has been armed with.
  internal struct ArmedOperation {
    /// The key C_SignInit selected.
    internal let key: SecKey

    /// The key's cryptosystem, which decides how the caller's input
    /// and the resulting signature are encoded.
    internal let kind: ModuleRegistry.KeyKind

    /// EC field width in bytes; zero for RSA.
    internal let width: Int

    /// The signature length this key produces, in bytes.
    internal let signatureLength: Int
  }

  /// A raw ECDSA signature concatenates two field-width halves.
  private static let signatureHalves = 2

  /// Standard hash output lengths in bytes.
  private static let sha224DigestLength = 28
  private static let sha256DigestLength = 32
  private static let sha384DigestLength = 48
  private static let sha512DigestLength = 64

  /// Digest algorithms keyed by digest length in bytes.
  ///
  /// CKM_ECDSA takes a pre-computed digest, and the token extension
  /// advertises the fixed-length X9.62 digest algorithms rather than
  /// the generic one, so the algorithm is chosen by the digest length
  /// the caller supplies.
  private static let digestAlgorithmsByLength: [Int: SecKeyAlgorithm] = [
    sha224DigestLength: .ecdsaSignatureDigestX962SHA224,
    sha256DigestLength: .ecdsaSignatureDigestX962SHA256,
    sha384DigestLength: .ecdsaSignatureDigestX962SHA384,
    sha512DigestLength: .ecdsaSignatureDigestX962SHA512,
  ]

  /// C_SignInit: validates mechanism and key, then arms the session.
  internal static func signInit(
    handle: CK_SESSION_HANDLE, mechanism: CK_MECHANISM_PTR?, key: CK_OBJECT_HANDLE
  ) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    guard let mechanism else { return CKR_ARGUMENTS_BAD }
    let requested = mechanism.pointee.mechanism
    return ModuleRegistry.shared.withLock { registry in
      guard let session = registry.sessions[handle] else {
        return CKR_SESSION_HANDLE_INVALID
      }
      guard session.signKey == nil else { return CKR_OPERATION_ACTIVE }
      guard let record = registry.object(handle: key),
        record.objectClass == CKO_PRIVATE_KEY,
        let privateKey = record.privateKey
      else { return CKR_KEY_HANDLE_INVALID }
      guard requested == signingMechanism(for: record.keyKind) else {
        return CKR_MECHANISM_INVALID
      }
      let chosen = boundKey(
        registry: registry, session: session, record: record, fallback: privateKey)
      registry.sessions[handle]?.signKey = chosen
      registry.sessions[handle]?.signKind = record.keyKind
      registry.sessions[handle]?.signWidth = record.fieldWidth
      registry.sessions[handle]?.signatureLength = record.signatureLength
      return CKR_OK
    }
  }

  /// The mechanism a key of this kind signs with.
  internal static func signingMechanism(for kind: ModuleRegistry.KeyKind) -> CK_MECHANISM_TYPE {
    switch kind {
    case .elliptic:
      return CKM_ECDSA

    case .rsa:
      return CKM_RSA_PKCS
    }
  }

  /// C_Sign: two-call convention, then one SecKeyCreateSignature call.
  internal static func sign(
    handle: CK_SESSION_HANDLE,
    data: CK_BYTE_PTR?,
    dataLength: CK_ULONG,
    signature: CK_BYTE_PTR?,
    signatureLength: CK_ULONG_PTR?
  ) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    guard let signatureLength else { return CKR_ARGUMENTS_BAD }
    guard let armed = armedOperation(handle: handle) else {
      return notArmedError(handle: handle)
    }
    let expected = CK_ULONG(armed.signatureLength)
    guard let signature else {
      signatureLength.pointee = expected
      return CKR_OK
    }
    guard signatureLength.pointee >= expected else {
      signatureLength.pointee = expected
      return CKR_BUFFER_TOO_SMALL
    }
    defer { disarm(handle: handle) }
    guard let data, dataLength > 0 else { return CKR_DATA_LEN_RANGE }
    let digest = Data(bytes: data, count: Int(dataLength))
    switch rawSignature(digest: digest, armed: armed) {
    case .signed(let raw):
      raw.withUnsafeBytes { bytes in
        guard let base = bytes.baseAddress else { return }
        UnsafeMutableRawPointer(signature).copyMemory(from: base, byteCount: bytes.count)
      }
      signatureLength.pointee = expected
      return CKR_OK

    case .failed(let code):
      return code
    }
  }

  /// The signing operation armed on this session, if any.
  ///
  /// Only the length query leaves it armed; producing a signature
  /// consumes it.
  private static func armedOperation(handle: CK_SESSION_HANDLE) -> ArmedOperation? {
    ModuleRegistry.shared.withLock { registry in
      guard let session = registry.sessions[handle], let key = session.signKey else {
        return nil
      }
      return ArmedOperation(
        key: key,
        kind: session.signKind,
        width: session.signWidth,
        signatureLength: session.signatureLength)
    }
  }

  /// Why no operation was armed: an unknown session, or a live one
  /// that never saw C_SignInit.
  private static func notArmedError(handle: CK_SESSION_HANDLE) -> CK_RV {
    ModuleRegistry.shared.withLock { registry in
      registry.sessions[handle] == nil
        ? CKR_SESSION_HANDLE_INVALID : CKR_OPERATION_NOT_INITIALIZED
    }
  }

  /// Signs one digest and returns the raw r||s form CKM_ECDSA wants,
  /// or the Cryptoki code describing the failure.
  ///
  /// Runs outside the registry lock: the system PIN dialog can block
  /// here for as long as the holder takes to answer it.
  private static func rawSignature(digest: Data, armed: ArmedOperation) -> SignOutcome {
    let plan: (input: Data, algorithm: SecKeyAlgorithm)?
    switch armed.kind {
    case .elliptic:
      plan = signatureAlgorithm(key: armed.key, digestLength: digest.count)
        .map { (digest, $0) }

    case .rsa:
      // CKM_RSA_PKCS carries a DigestInfo the caller built; the key
      // signs a bare digest under the algorithm that DigestInfo names.
      plan = RsaEncoding.digest(fromDigestInfo: digest)
        .flatMap { parsed in
          SecKeyIsAlgorithmSupported(armed.key, .sign, parsed.algorithm)
            ? (parsed.value, parsed.algorithm) : nil
        }
    }
    guard let plan else {
      return .failed(armed.kind == .rsa ? CKR_DATA_INVALID : CKR_DATA_LEN_RANGE)
    }
    var errorReference: Unmanaged<CFError>?
    let signature = SecKeyCreateSignature(
      armed.key, plan.algorithm, plan.input as CFData, &errorReference)
    guard let signature else {
      let status = errorReference.map { CFErrorGetCode($0.takeRetainedValue()) }
      return .failed(signError(status: status))
    }
    guard armed.kind == .elliptic else { return .signed(signature as Data) }
    guard
      let raw = EcEncoding.rawSignature(
        fromDer: signature as Data, fieldWidth: armed.width)
    else { return .failed(CKR_GENERAL_ERROR) }
    return .signed(raw)
  }

  /// The X9.62 digest algorithm the key supports for a digest of the
  /// given length: the length-specific one first, then the generic
  /// one, nil if neither is supported.
  private static func signatureAlgorithm(
    key: SecKey, digestLength: Int
  ) -> SecKeyAlgorithm? {
    var candidates: [SecKeyAlgorithm] = []
    if let specific = digestAlgorithmsByLength[digestLength] {
      candidates.append(specific)
    }
    candidates.append(.ecdsaSignatureDigestX962)
    return candidates.first { SecKeyIsAlgorithmSupported(key, .sign, $0) }
  }

  /// Maps a SecKeyCreateSignature failure to a Cryptoki return value:
  /// a cancelled PIN dialog to CKR_FUNCTION_CANCELED, a rejected PIN
  /// to CKR_PIN_INCORRECT, anything else to CKR_FUNCTION_FAILED.
  private static func signError(status: CFIndex?) -> CK_RV {
    switch status {
    case CFIndex(errSecUserCanceled):
      return CKR_FUNCTION_CANCELED

    case CFIndex(errSecAuthFailed):
      return CKR_PIN_INCORRECT

    default:
      return CKR_FUNCTION_FAILED
    }
  }

  /// Picks the PIN-bound key when C_Login supplied a PIN, otherwise
  /// the snapshot key (protected authentication path).
  private static func boundKey(
    registry: ModuleRegistry,
    session: ModuleRegistry.SessionRecord,
    record: ModuleRegistry.ObjectRecord,
    fallback: SecKey
  ) -> SecKey {
    guard let token = registry.token(slotID: session.slotID),
      let context = token.authenticationContext,
      let keyID = record.attributes[CKA_ID],
      let bound = TokenCatalog.authenticatedKey(
        tokenID: token.tokenID, keyID: keyID, context: context)
    else { return fallback }
    return bound
  }

  /// Clears the armed signing operation.
  private static func disarm(handle: CK_SESSION_HANDLE) {
    ModuleRegistry.shared.withLock { registry in
      registry.sessions[handle]?.signKey = nil
      registry.sessions[handle]?.signWidth = 0
    }
  }
}

/// Exported C_SignInit; see SignEntryPoints.signInit.
@_cdecl("C_SignInit")
internal func cryptokiSignInit(
  _ handle: CK_SESSION_HANDLE, _ mechanism: CK_MECHANISM_PTR?, _ key: CK_OBJECT_HANDLE
) -> CK_RV {
  SignEntryPoints.signInit(handle: handle, mechanism: mechanism, key: key)
}

/// Exported C_Sign; see SignEntryPoints.sign.
@_cdecl("C_Sign")
internal func cryptokiSign(
  _ handle: CK_SESSION_HANDLE,
  _ data: CK_BYTE_PTR?,
  _ dataLength: CK_ULONG,
  _ signature: CK_BYTE_PTR?,
  _ signatureLength: CK_ULONG_PTR?
) -> CK_RV {
  SignEntryPoints.sign(
    handle: handle,
    data: data,
    dataLength: dataLength,
    signature: signature,
    signatureLength: signatureLength)
}
