// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

/// Symbol animations used on every platform this app supports.
extension View {
  /// Pulses the symbol once whenever the value changes.
  internal func pulsingSymbol(value: some Equatable) -> some View {
    symbolEffect(.pulse, value: value)
  }

  /// Bounces the symbol repeatedly until the value changes.
  internal func bouncingSymbol(value: some Equatable) -> some View {
    symbolEffect(.bounce, options: .repeating, value: value)
  }

  /// Replaces one symbol with another in place.
  ///
  /// The magic replacement carries layers across the change, and falls
  /// back to the upward slide where the system has no layers.
  internal func replacingSymbol() -> some View {
    contentTransition(
      .symbolEffect(
        .replace.magic(fallback: .offUp.byLayer),
        options: .nonRepeating)
    )
  }

  /// Replaces one symbol with another without the layered fallback.
  internal func replacingSymbolPlainly() -> some View {
    contentTransition(.symbolEffect(.replace))
  }
}
