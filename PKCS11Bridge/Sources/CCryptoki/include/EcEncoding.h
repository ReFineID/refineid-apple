// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

// EcEncoding.h -- named protocol values for the EC encodings the bridge
// translates between Security.framework and PKCS#11.
//
// CKA_EC_PARAMS carries the DER-encoded named-curve OID (SEC 1 /
// RFC 5480: secp256r1 1.2.840.10045.3.1.7, secp384r1 1.3.132.0.34,
// secp521r1 1.3.132.0.35). CKA_EC_POINT carries the uncompressed
// SEC 1 point wrapped in a DER OCTET STRING. CKM_ECDSA signatures are
// the raw r||s concatenation, whereas SecKeyCreateSignature produces
// X9.62 DER SEQUENCE { INTEGER r, INTEGER s }; the bridge converts.

#ifndef REFINEID_EC_ENCODING_H
#define REFINEID_EC_ENCODING_H

#include "Cryptoki.h"

// DER universal tags and length encoding.
static const CK_BYTE Asn1IntegerTag = 0x02;
static const CK_BYTE Asn1OctetStringTag = 0x04;
static const CK_BYTE Asn1ObjectIdentifierTag = 0x06;
static const CK_BYTE Asn1SequenceTag = 0x30;
// Length octets with this bit set carry the count of following length
// octets (DER long form); without it they carry the length itself.
static const CK_BYTE Asn1LongFormLengthFlag = 0x80;

// SEC 1 uncompressed-point marker: 0x04 || X || Y.
static const CK_BYTE EcUncompressedPointTag = 0x04;

// DER-encoded named-curve OIDs for CKA_EC_PARAMS.
static const CK_BYTE EcParamsP256[] = {
  0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07};
static const CK_BYTE EcParamsP384[] = {0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22};
static const CK_BYTE EcParamsP521[] = {0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23};

// Field element widths in bytes; an uncompressed point is 1 + 2 * width
// and a raw CKM_ECDSA signature is 2 * width.
static const CK_ULONG EcFieldBytesP256 = 32;
static const CK_ULONG EcFieldBytesP384 = 48;
static const CK_ULONG EcFieldBytesP521 = 66;

#endif
