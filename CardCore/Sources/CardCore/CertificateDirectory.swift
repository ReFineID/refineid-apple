// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The directory a certificate file lives under, which the reader must
/// make current before selecting the file (FINEID S4-1 §3, S4-2 v4.0
/// §4.6).
public enum CertificateDirectory: Equatable, Sendable {
  /// DF.ESIGN (5016) under the main file, where the organization
  /// card keeps its signature certificate (FINEID S4-2 v4.0
  /// §4.6.21-4.6.22).
  case esignApplication

  /// Directly under the main file (ISO 7816-4 MF, FID 3F00).
  case mainFile

  /// Directly under the PKCS#15 application DF (already current after
  /// selecting the eID application).
  case pkcs15Application
}
