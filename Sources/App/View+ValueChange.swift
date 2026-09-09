// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import SwiftUI

extension View {
  /// Runs an action when a value changes.
  @ViewBuilder
  internal func onValueChange<Value: Equatable>(
    of value: Value,
    perform action: @escaping (Value) -> Void
  ) -> some View {
    onChange(of: value) { _, updated in action(updated) }
  }
}
