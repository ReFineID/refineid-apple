// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import CCryptoki
import Foundation

/// Object management entry points (spec section 5.7): find operations
/// and attribute readout over the precomputed object records.
internal enum ObjectEntryPoints {
  /// C_FindObjectsInit: captures the template and computes the matches
  /// from the session's token.
  internal static func findInit(
    handle: CK_SESSION_HANDLE, template: CK_ATTRIBUTE_PTR?, count: CK_ULONG
  ) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    guard template != nil || count == 0 else { return CKR_ARGUMENTS_BAD }
    return ModuleRegistry.shared.withLock { registry in
      guard let session = registry.sessions[handle] else {
        return CKR_SESSION_HANDLE_INVALID
      }
      guard !session.findActive else { return CKR_OPERATION_ACTIVE }
      var wanted: [CK_ATTRIBUTE_TYPE: Data] = [:]
      if let template {
        for index in 0..<Int(count) {
          let attribute = template[index]
          let length = Int(attribute.ulValueLen)
          if let value = attribute.pValue, length > 0 {
            wanted[attribute.type] = Data(bytes: value, count: length)
          } else {
            wanted[attribute.type] = Data()
          }
        }
      }
      let objects = registry.token(slotID: session.slotID)?.objects ?? []
      let matches = objects.filter { object in
        wanted.allSatisfy { type, value in object.attributes[type] == value }
      }
      registry.sessions[handle]?.findActive = true
      registry.sessions[handle]?.findResults = matches.map(\.handle)
      registry.sessions[handle]?.findIndex = 0
      return CKR_OK
    }
  }

  /// C_FindObjects: returns the next batch of matches.
  internal static func find(
    handle: CK_SESSION_HANDLE,
    objects: CK_OBJECT_HANDLE_PTR?,
    maxCount: CK_ULONG,
    count: CK_ULONG_PTR?
  ) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    guard let objects, let count else { return CKR_ARGUMENTS_BAD }
    return ModuleRegistry.shared.withLock { registry in
      guard let session = registry.sessions[handle] else {
        return CKR_SESSION_HANDLE_INVALID
      }
      guard session.findActive else { return CKR_OPERATION_NOT_INITIALIZED }
      let remaining = session.findResults[session.findIndex...]
      let batch = remaining.prefix(Int(maxCount))
      for (offset, objectHandle) in batch.enumerated() {
        objects[offset] = objectHandle
      }
      registry.sessions[handle]?.findIndex = session.findIndex + batch.count
      count.pointee = CK_ULONG(batch.count)
      return CKR_OK
    }
  }

  /// C_FindObjectsFinal.
  internal static func findFinal(handle: CK_SESSION_HANDLE) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    return ModuleRegistry.shared.withLock { registry in
      guard let session = registry.sessions[handle] else {
        return CKR_SESSION_HANDLE_INVALID
      }
      guard session.findActive else { return CKR_OPERATION_NOT_INITIALIZED }
      registry.sessions[handle]?.findActive = false
      registry.sessions[handle]?.findResults = []
      registry.sessions[handle]?.findIndex = 0
      return CKR_OK
    }
  }

  /// C_GetAttributeValue with the four-case semantics of spec section
  /// 5.7.5: length query, copy, CKR_BUFFER_TOO_SMALL, and
  /// CKR_ATTRIBUTE_TYPE_INVALID with CK_UNAVAILABLE_INFORMATION.
  internal static func attributeValues(
    handle: CK_SESSION_HANDLE,
    object: CK_OBJECT_HANDLE,
    template: CK_ATTRIBUTE_PTR?,
    count: CK_ULONG
  ) -> CK_RV {
    guard CryptokiEntryPoints.isLive else { return CKR_CRYPTOKI_NOT_INITIALIZED }
    guard let template else { return CKR_ARGUMENTS_BAD }
    return ModuleRegistry.shared.withLock { registry in
      guard registry.sessions[handle] != nil else {
        return CKR_SESSION_HANDLE_INVALID
      }
      guard let record = registry.object(handle: object) else {
        return CKR_OBJECT_HANDLE_INVALID
      }
      var result = CKR_OK
      for index in 0..<Int(count) {
        result = worse(
          result, fill(attribute: &template[index], from: record.attributes))
      }
      return result
    }
  }

  /// Serves one template entry from the attribute dictionary.
  private static func fill(
    attribute: inout CK_ATTRIBUTE, from attributes: [CK_ATTRIBUTE_TYPE: Data]
  ) -> CK_RV {
    guard let value = attributes[attribute.type] else {
      attribute.ulValueLen = CK_UNAVAILABLE_INFORMATION
      return CKR_ATTRIBUTE_TYPE_INVALID
    }
    guard let destination = attribute.pValue else {
      attribute.ulValueLen = CK_ULONG(value.count)
      return CKR_OK
    }
    guard Int(attribute.ulValueLen) >= value.count else {
      attribute.ulValueLen = CK_UNAVAILABLE_INFORMATION
      return CKR_BUFFER_TOO_SMALL
    }
    value.withUnsafeBytes { bytes in
      guard let base = bytes.baseAddress else { return }
      destination.copyMemory(from: base, byteCount: bytes.count)
    }
    attribute.ulValueLen = CK_ULONG(value.count)
    return CKR_OK
  }

  /// Keeps the more severe of two attribute results; CKR_OK is weakest.
  private static func worse(_ current: CK_RV, _ candidate: CK_RV) -> CK_RV {
    current == CKR_OK ? candidate : current
  }
}

/// Exported C_FindObjectsInit; see ObjectEntryPoints.findInit.
@_cdecl("C_FindObjectsInit")
internal func cryptokiFindObjectsInit(
  _ handle: CK_SESSION_HANDLE, _ template: CK_ATTRIBUTE_PTR?, _ count: CK_ULONG
) -> CK_RV {
  ObjectEntryPoints.findInit(handle: handle, template: template, count: count)
}

/// Exported C_FindObjects; see ObjectEntryPoints.find.
@_cdecl("C_FindObjects")
internal func cryptokiFindObjects(
  _ handle: CK_SESSION_HANDLE,
  _ objects: CK_OBJECT_HANDLE_PTR?,
  _ maxCount: CK_ULONG,
  _ count: CK_ULONG_PTR?
) -> CK_RV {
  ObjectEntryPoints.find(handle: handle, objects: objects, maxCount: maxCount, count: count)
}

/// Exported C_FindObjectsFinal; see ObjectEntryPoints.findFinal.
@_cdecl("C_FindObjectsFinal")
internal func cryptokiFindObjectsFinal(_ handle: CK_SESSION_HANDLE) -> CK_RV {
  ObjectEntryPoints.findFinal(handle: handle)
}

/// Exported C_GetAttributeValue; see ObjectEntryPoints.attributeValues.
@_cdecl("C_GetAttributeValue")
internal func cryptokiGetAttributeValue(
  _ handle: CK_SESSION_HANDLE,
  _ object: CK_OBJECT_HANDLE,
  _ template: CK_ATTRIBUTE_PTR?,
  _ count: CK_ULONG
) -> CK_RV {
  ObjectEntryPoints.attributeValues(
    handle: handle, object: object, template: template, count: count)
}
