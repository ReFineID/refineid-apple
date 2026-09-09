// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// FunctionList.c -- the exported function lists, interface discovery,
// and the entry-point stubs the bridge does not implement.
//
// PKCS#11 requires every member of a function list to be a valid
// pointer, so unimplemented entry points are concrete functions
// returning CKR_FUNCTION_NOT_SUPPORTED (the standard's return value for
// exactly this), except the legacy parallel-management pair, which the
// spec requires to return CKR_FUNCTION_NOT_PARALLEL. The module
// implements PKCS#11 3.2: C_GetInterfaceList/C_GetInterface publish the
// 3.2, 3.0, and legacy 2.40 "PKCS 11" interfaces, and C_GetFunctionList
// serves legacy consumers with the 2.40 list (whose version field the
// spec fixes at 2.40). C_Initialize, C_Finalize, C_GetInfo, and
// C_GetSlotList are implemented in Swift (PKCS11Bridge target) and
// referenced here by their prototypes; the linker binds them when the
// dynamic library or a test bundle is produced. The slot, token,
// session, object, and single-part signing entry points are implemented
// in Swift as well.

#include <string.h>

#include "include/Cryptoki.h"

CK_RV C_InitToken(
  CK_SLOT_ID slotID, CK_UTF8CHAR_PTR pPin, CK_ULONG ulPinLen, CK_UTF8CHAR_PTR pLabel) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_InitPIN(CK_SESSION_HANDLE hSession, CK_UTF8CHAR_PTR pPin, CK_ULONG ulPinLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SetPIN(
  CK_SESSION_HANDLE hSession, CK_UTF8CHAR_PTR pOldPin, CK_ULONG ulOldLen,
  CK_UTF8CHAR_PTR pNewPin, CK_ULONG ulNewLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GetOperationState(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pOperationState,
  CK_ULONG_PTR pulOperationStateLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SetOperationState(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pOperationState,
  CK_ULONG ulOperationStateLen, CK_OBJECT_HANDLE hEncryptionKey,
  CK_OBJECT_HANDLE hAuthenticationKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_CreateObject(
  CK_SESSION_HANDLE hSession, CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulCount,
  CK_OBJECT_HANDLE_PTR phObject) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_CopyObject(
  CK_SESSION_HANDLE hSession, CK_OBJECT_HANDLE hObject, CK_ATTRIBUTE_PTR pTemplate,
  CK_ULONG ulCount, CK_OBJECT_HANDLE_PTR phNewObject) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DestroyObject(CK_SESSION_HANDLE hSession, CK_OBJECT_HANDLE hObject) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GetObjectSize(
  CK_SESSION_HANDLE hSession, CK_OBJECT_HANDLE hObject, CK_ULONG_PTR pulSize) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SetAttributeValue(
  CK_SESSION_HANDLE hSession, CK_OBJECT_HANDLE hObject, CK_ATTRIBUTE_PTR pTemplate,
  CK_ULONG ulCount) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_Encrypt(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pData, CK_ULONG ulDataLen,
  CK_BYTE_PTR pEncryptedData, CK_ULONG_PTR pulEncryptedDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen,
  CK_BYTE_PTR pEncryptedPart, CK_ULONG_PTR pulEncryptedPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptFinal(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pLastEncryptedPart,
  CK_ULONG_PTR pulLastEncryptedPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_Decrypt(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pEncryptedData, CK_ULONG ulEncryptedDataLen,
  CK_BYTE_PTR pData, CK_ULONG_PTR pulDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pEncryptedPart, CK_ULONG ulEncryptedPartLen,
  CK_BYTE_PTR pPart, CK_ULONG_PTR pulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptFinal(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pLastPart, CK_ULONG_PTR pulLastPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DigestInit(CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_Digest(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pData, CK_ULONG ulDataLen,
  CK_BYTE_PTR pDigest, CK_ULONG_PTR pulDigestLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DigestUpdate(CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DigestKey(CK_SESSION_HANDLE hSession, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DigestFinal(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pDigest, CK_ULONG_PTR pulDigestLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignUpdate(CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignFinal(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pSignature, CK_ULONG_PTR pulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignRecoverInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignRecover(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pData, CK_ULONG ulDataLen,
  CK_BYTE_PTR pSignature, CK_ULONG_PTR pulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_Verify(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pData, CK_ULONG ulDataLen,
  CK_BYTE_PTR pSignature, CK_ULONG ulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyUpdate(CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyFinal(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pSignature, CK_ULONG ulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyRecoverInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyRecover(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pSignature, CK_ULONG ulSignatureLen,
  CK_BYTE_PTR pData, CK_ULONG_PTR pulDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DigestEncryptUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen,
  CK_BYTE_PTR pEncryptedPart, CK_ULONG_PTR pulEncryptedPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptDigestUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pEncryptedPart, CK_ULONG ulEncryptedPartLen,
  CK_BYTE_PTR pPart, CK_ULONG_PTR pulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignEncryptUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen,
  CK_BYTE_PTR pEncryptedPart, CK_ULONG_PTR pulEncryptedPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptVerifyUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pEncryptedPart, CK_ULONG ulEncryptedPartLen,
  CK_BYTE_PTR pPart, CK_ULONG_PTR pulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GenerateKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_ATTRIBUTE_PTR pTemplate,
  CK_ULONG ulCount, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GenerateKeyPair(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism,
  CK_ATTRIBUTE_PTR pPublicKeyTemplate, CK_ULONG ulPublicKeyAttributeCount,
  CK_ATTRIBUTE_PTR pPrivateKeyTemplate, CK_ULONG ulPrivateKeyAttributeCount,
  CK_OBJECT_HANDLE_PTR phPublicKey, CK_OBJECT_HANDLE_PTR phPrivateKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_WrapKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism,
  CK_OBJECT_HANDLE hWrappingKey, CK_OBJECT_HANDLE hKey, CK_BYTE_PTR pWrappedKey,
  CK_ULONG_PTR pulWrappedKeyLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_UnwrapKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism,
  CK_OBJECT_HANDLE hUnwrappingKey, CK_BYTE_PTR pWrappedKey, CK_ULONG ulWrappedKeyLen,
  CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulAttributeCount, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DeriveKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hBaseKey,
  CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulAttributeCount, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SeedRandom(CK_SESSION_HANDLE hSession, CK_BYTE_PTR pSeed, CK_ULONG ulSeedLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GenerateRandom(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pRandomData, CK_ULONG ulRandomLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

// The two legacy parallel-management functions must return
// CKR_FUNCTION_NOT_PARALLEL, not CKR_FUNCTION_NOT_SUPPORTED
// (spec sections 5.20.1 and 5.20.2).
CK_RV C_GetFunctionStatus(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_PARALLEL;
}

CK_RV C_CancelFunction(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_PARALLEL;
}

CK_RV C_WaitForSlotEvent(CK_FLAGS flags, CK_SLOT_ID_PTR pSlot, CK_VOID_PTR pReserved) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

// Stubs for the entry points added in PKCS#11 3.0 and 3.2 that the
// bridge does not (yet) implement.

CK_RV C_LoginUser(
  CK_SESSION_HANDLE hSession, CK_USER_TYPE userType, CK_UTF8CHAR_PTR pPin,
  CK_ULONG ulPinLen, CK_UTF8CHAR_PTR pUsername, CK_ULONG ulUsernameLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SessionCancel(CK_SESSION_HANDLE hSession, CK_FLAGS flags) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageEncryptInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptMessage(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pAssociatedData, CK_ULONG ulAssociatedDataLen, CK_BYTE_PTR pPlaintext,
  CK_ULONG ulPlaintextLen, CK_BYTE_PTR pCiphertext, CK_ULONG_PTR pulCiphertextLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptMessageBegin(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pAssociatedData, CK_ULONG ulAssociatedDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncryptMessageNext(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pPlaintextPart, CK_ULONG ulPlaintextPartLen, CK_BYTE_PTR pCiphertextPart,
  CK_ULONG_PTR pulCiphertextPartLen, CK_FLAGS flags) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageEncryptFinal(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageDecryptInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptMessage(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pAssociatedData, CK_ULONG ulAssociatedDataLen, CK_BYTE_PTR pCiphertext,
  CK_ULONG ulCiphertextLen, CK_BYTE_PTR pPlaintext, CK_ULONG_PTR pulPlaintextLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptMessageBegin(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pAssociatedData, CK_ULONG ulAssociatedDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecryptMessageNext(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pCiphertextPart, CK_ULONG ulCiphertextPartLen, CK_BYTE_PTR pPlaintextPart,
  CK_ULONG_PTR pulPlaintextPartLen, CK_FLAGS flags) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageDecryptFinal(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageSignInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignMessage(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pData, CK_ULONG ulDataLen, CK_BYTE_PTR pSignature,
  CK_ULONG_PTR pulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignMessageBegin(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_SignMessageNext(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pData, CK_ULONG ulDataLen, CK_BYTE_PTR pSignature,
  CK_ULONG_PTR pulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageSignFinal(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageVerifyInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyMessage(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pData, CK_ULONG ulDataLen, CK_BYTE_PTR pSignature,
  CK_ULONG ulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyMessageBegin(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifyMessageNext(
  CK_SESSION_HANDLE hSession, CK_VOID_PTR pParameter, CK_ULONG ulParameterLen,
  CK_BYTE_PTR pData, CK_ULONG ulDataLen, CK_BYTE_PTR pSignature,
  CK_ULONG ulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_MessageVerifyFinal(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_EncapsulateKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hPublicKey,
  CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulAttributeCount, CK_BYTE_PTR pCiphertext,
  CK_ULONG_PTR pulCiphertextLen, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_DecapsulateKey(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hPrivateKey,
  CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulAttributeCount, CK_BYTE_PTR pCiphertext,
  CK_ULONG ulCiphertextLen, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifySignatureInit(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism, CK_OBJECT_HANDLE hKey,
  CK_BYTE_PTR pSignature, CK_ULONG ulSignatureLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifySignature(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pData, CK_ULONG ulDataLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifySignatureUpdate(
  CK_SESSION_HANDLE hSession, CK_BYTE_PTR pPart, CK_ULONG ulPartLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_VerifySignatureFinal(CK_SESSION_HANDLE hSession) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_GetSessionValidationFlags(
  CK_SESSION_HANDLE hSession, CK_SESSION_VALIDATION_FLAGS_TYPE type,
  CK_FLAGS_PTR pFlags) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_AsyncComplete(
  CK_SESSION_HANDLE hSession, CK_UTF8CHAR_PTR pFunctionName,
  CK_ASYNC_DATA_PTR pResult) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_AsyncGetID(
  CK_SESSION_HANDLE hSession, CK_UTF8CHAR_PTR pFunctionName, CK_ULONG_PTR pulID) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_AsyncJoin(
  CK_SESSION_HANDLE hSession, CK_UTF8CHAR_PTR pFunctionName, CK_ULONG ulID,
  CK_BYTE_PTR pData, CK_ULONG ulData) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_WrapKeyAuthenticated(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism,
  CK_OBJECT_HANDLE hWrappingKey, CK_OBJECT_HANDLE hKey, CK_BYTE_PTR pAssociatedData,
  CK_ULONG ulAssociatedDataLen, CK_BYTE_PTR pWrappedKey,
  CK_ULONG_PTR pulWrappedKeyLen) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

CK_RV C_UnwrapKeyAuthenticated(
  CK_SESSION_HANDLE hSession, CK_MECHANISM_PTR pMechanism,
  CK_OBJECT_HANDLE hUnwrappingKey, CK_BYTE_PTR pWrappedKey, CK_ULONG ulWrappedKeyLen,
  CK_ATTRIBUTE_PTR pTemplate, CK_ULONG ulAttributeCount, CK_BYTE_PTR pAssociatedData,
  CK_ULONG ulAssociatedDataLen, CK_OBJECT_HANDLE_PTR phKey) {
  return CKR_FUNCTION_NOT_SUPPORTED;
}

// The exported function lists. Version macros are used directly because
// a C static initializer cannot reference const objects; the shared
// member runs come from initializer macros so the three lists cannot
// drift apart.

#define REFINEID_FUNCTION_INIT_2_40 \
  .C_Initialize = C_Initialize, \
  .C_Finalize = C_Finalize, \
  .C_GetInfo = C_GetInfo, \
  .C_GetFunctionList = C_GetFunctionList, \
  .C_GetSlotList = C_GetSlotList, \
  .C_GetSlotInfo = C_GetSlotInfo, \
  .C_GetTokenInfo = C_GetTokenInfo, \
  .C_GetMechanismList = C_GetMechanismList, \
  .C_GetMechanismInfo = C_GetMechanismInfo, \
  .C_InitToken = C_InitToken, \
  .C_InitPIN = C_InitPIN, \
  .C_SetPIN = C_SetPIN, \
  .C_OpenSession = C_OpenSession, \
  .C_CloseSession = C_CloseSession, \
  .C_CloseAllSessions = C_CloseAllSessions, \
  .C_GetSessionInfo = C_GetSessionInfo, \
  .C_GetOperationState = C_GetOperationState, \
  .C_SetOperationState = C_SetOperationState, \
  .C_Login = C_Login, \
  .C_Logout = C_Logout, \
  .C_CreateObject = C_CreateObject, \
  .C_CopyObject = C_CopyObject, \
  .C_DestroyObject = C_DestroyObject, \
  .C_GetObjectSize = C_GetObjectSize, \
  .C_GetAttributeValue = C_GetAttributeValue, \
  .C_SetAttributeValue = C_SetAttributeValue, \
  .C_FindObjectsInit = C_FindObjectsInit, \
  .C_FindObjects = C_FindObjects, \
  .C_FindObjectsFinal = C_FindObjectsFinal, \
  .C_EncryptInit = C_EncryptInit, \
  .C_Encrypt = C_Encrypt, \
  .C_EncryptUpdate = C_EncryptUpdate, \
  .C_EncryptFinal = C_EncryptFinal, \
  .C_DecryptInit = C_DecryptInit, \
  .C_Decrypt = C_Decrypt, \
  .C_DecryptUpdate = C_DecryptUpdate, \
  .C_DecryptFinal = C_DecryptFinal, \
  .C_DigestInit = C_DigestInit, \
  .C_Digest = C_Digest, \
  .C_DigestUpdate = C_DigestUpdate, \
  .C_DigestKey = C_DigestKey, \
  .C_DigestFinal = C_DigestFinal, \
  .C_SignInit = C_SignInit, \
  .C_Sign = C_Sign, \
  .C_SignUpdate = C_SignUpdate, \
  .C_SignFinal = C_SignFinal, \
  .C_SignRecoverInit = C_SignRecoverInit, \
  .C_SignRecover = C_SignRecover, \
  .C_VerifyInit = C_VerifyInit, \
  .C_Verify = C_Verify, \
  .C_VerifyUpdate = C_VerifyUpdate, \
  .C_VerifyFinal = C_VerifyFinal, \
  .C_VerifyRecoverInit = C_VerifyRecoverInit, \
  .C_VerifyRecover = C_VerifyRecover, \
  .C_DigestEncryptUpdate = C_DigestEncryptUpdate, \
  .C_DecryptDigestUpdate = C_DecryptDigestUpdate, \
  .C_SignEncryptUpdate = C_SignEncryptUpdate, \
  .C_DecryptVerifyUpdate = C_DecryptVerifyUpdate, \
  .C_GenerateKey = C_GenerateKey, \
  .C_GenerateKeyPair = C_GenerateKeyPair, \
  .C_WrapKey = C_WrapKey, \
  .C_UnwrapKey = C_UnwrapKey, \
  .C_DeriveKey = C_DeriveKey, \
  .C_SeedRandom = C_SeedRandom, \
  .C_GenerateRandom = C_GenerateRandom, \
  .C_GetFunctionStatus = C_GetFunctionStatus, \
  .C_CancelFunction = C_CancelFunction, \
  .C_WaitForSlotEvent = C_WaitForSlotEvent

#define REFINEID_FUNCTION_INIT_3_0 \
  .C_GetInterfaceList = C_GetInterfaceList, \
  .C_GetInterface = C_GetInterface, \
  .C_LoginUser = C_LoginUser, \
  .C_SessionCancel = C_SessionCancel, \
  .C_MessageEncryptInit = C_MessageEncryptInit, \
  .C_EncryptMessage = C_EncryptMessage, \
  .C_EncryptMessageBegin = C_EncryptMessageBegin, \
  .C_EncryptMessageNext = C_EncryptMessageNext, \
  .C_MessageEncryptFinal = C_MessageEncryptFinal, \
  .C_MessageDecryptInit = C_MessageDecryptInit, \
  .C_DecryptMessage = C_DecryptMessage, \
  .C_DecryptMessageBegin = C_DecryptMessageBegin, \
  .C_DecryptMessageNext = C_DecryptMessageNext, \
  .C_MessageDecryptFinal = C_MessageDecryptFinal, \
  .C_MessageSignInit = C_MessageSignInit, \
  .C_SignMessage = C_SignMessage, \
  .C_SignMessageBegin = C_SignMessageBegin, \
  .C_SignMessageNext = C_SignMessageNext, \
  .C_MessageSignFinal = C_MessageSignFinal, \
  .C_MessageVerifyInit = C_MessageVerifyInit, \
  .C_VerifyMessage = C_VerifyMessage, \
  .C_VerifyMessageBegin = C_VerifyMessageBegin, \
  .C_VerifyMessageNext = C_VerifyMessageNext, \
  .C_MessageVerifyFinal = C_MessageVerifyFinal

#define REFINEID_FUNCTION_INIT_3_2 \
  .C_EncapsulateKey = C_EncapsulateKey, \
  .C_DecapsulateKey = C_DecapsulateKey, \
  .C_VerifySignatureInit = C_VerifySignatureInit, \
  .C_VerifySignature = C_VerifySignature, \
  .C_VerifySignatureUpdate = C_VerifySignatureUpdate, \
  .C_VerifySignatureFinal = C_VerifySignatureFinal, \
  .C_GetSessionValidationFlags = C_GetSessionValidationFlags, \
  .C_AsyncComplete = C_AsyncComplete, \
  .C_AsyncGetID = C_AsyncGetID, \
  .C_AsyncJoin = C_AsyncJoin, \
  .C_WrapKeyAuthenticated = C_WrapKeyAuthenticated, \
  .C_UnwrapKeyAuthenticated = C_UnwrapKeyAuthenticated

// The legacy list version is fixed at 2.40 by the specification's
// C_GetFunctionList description; the current lists carry their own
// versions and are published through C_GetInterfaceList/C_GetInterface.
static CK_FUNCTION_LIST FunctionList = {
  .version = {CRYPTOKI_LEGACY_VERSION_MAJOR, CRYPTOKI_LEGACY_VERSION_MINOR},
  REFINEID_FUNCTION_INIT_2_40,
};

static CK_FUNCTION_LIST_3_0 FunctionList30 = {
  .version = {3, 0},
  REFINEID_FUNCTION_INIT_2_40,
  REFINEID_FUNCTION_INIT_3_0,
};

static CK_FUNCTION_LIST_3_2 FunctionList32 = {
  .version = {CRYPTOKI_VERSION_MAJOR, CRYPTOKI_VERSION_MINOR},
  REFINEID_FUNCTION_INIT_2_40,
  REFINEID_FUNCTION_INIT_3_0,
  REFINEID_FUNCTION_INIT_3_2,
};

CK_RV C_GetFunctionList(CK_FUNCTION_LIST_PTR_PTR ppFunctionList) {
  if (ppFunctionList == 0) {
    return CKR_ARGUMENTS_BAD;
  }
  *ppFunctionList = &FunctionList;
  return CKR_OK;
}

// The standard interface name (spec section 5.4, C_GetInterface).
// All three published interfaces share it; their versions are read from
// the CK_VERSION at the start of each function list. None claims
// CKF_INTERFACE_FORK_SAFE.
static CK_UTF8CHAR InterfaceName[] = "PKCS 11";

static CK_INTERFACE Interfaces[] = {
  {InterfaceName, &FunctionList32, 0},
  {InterfaceName, &FunctionList30, 0},
  {InterfaceName, &FunctionList, 0},
};

static const CK_ULONG InterfaceCount = sizeof(Interfaces) / sizeof(Interfaces[0]);

CK_RV C_GetInterfaceList(CK_INTERFACE_PTR pInterfacesList, CK_ULONG_PTR pulCount) {
  if (pulCount == 0) {
    return CKR_ARGUMENTS_BAD;
  }
  if (pInterfacesList == 0) {
    *pulCount = InterfaceCount;
    return CKR_OK;
  }
  if (*pulCount < InterfaceCount) {
    *pulCount = InterfaceCount;
    return CKR_BUFFER_TOO_SMALL;
  }
  memcpy(pInterfacesList, Interfaces, sizeof(Interfaces));
  *pulCount = InterfaceCount;
  return CKR_OK;
}

CK_RV C_GetInterface(
  CK_UTF8CHAR_PTR pInterfaceName, CK_VERSION_PTR pVersion,
  CK_INTERFACE_PTR_PTR ppInterface, CK_FLAGS flags) {
  if (ppInterface == 0) {
    return CKR_ARGUMENTS_BAD;
  }
  for (CK_ULONG index = 0; index < InterfaceCount; index += 1) {
    CK_INTERFACE_PTR candidate = &Interfaces[index];
    const CK_VERSION *candidateVersion = candidate->pFunctionList;
    if (pInterfaceName != 0
        && strcmp((const char *)pInterfaceName, (const char *)candidate->pInterfaceName)
          != 0) {
      continue;
    }
    if (pVersion != 0
        && (pVersion->major != candidateVersion->major
            || pVersion->minor != candidateVersion->minor)) {
      continue;
    }
    if ((candidate->flags & flags) != flags) {
      continue;
    }
    *ppInterface = candidate;
    return CKR_OK;
  }
  return CKR_ARGUMENTS_BAD;
}
