// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#include <stdint.h>

/// Resets the card in the named PC/SC reader, making the system
/// re-evaluate what the card is.
///
/// C, because the PCSC module is marked unimportable from Swift while
/// its C interface remains fully supported.
///
/// Returns 0 when the reset went through, or the failing call's
/// PC/SC status.
int32_t CardCoreResetCard(const char *readerName);
