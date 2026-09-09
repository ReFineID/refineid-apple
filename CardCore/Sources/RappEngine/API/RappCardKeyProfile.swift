// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// The key a card operation uses.
public enum RappCardKeyProfile: Sendable {
  case ecdsaP256
  case ecdsaP384
  case rsa2048
  case rsa3072
}
