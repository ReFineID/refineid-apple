// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A registered signature algorithm.
public enum RappSignatureAlgorithm: Sendable {
  case ecdsaSha224
  case ecdsaSha256
  case ecdsaSha384
  case ecdsaSha512
  case rsaPkcs1Sha256
  case rsaPkcs1Sha384
  case rsaPkcs1Sha512
  case rsaPssSha256
}
