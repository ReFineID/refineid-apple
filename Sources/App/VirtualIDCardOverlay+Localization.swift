// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import Foundation

  internal func virtualCardLocalized(
    _ key: StaticString,
    defaultValue: String.LocalizationValue
  ) -> String {
    VirtualIDCardOverlayLocalization.localizedText(
      key,
      defaultValue: defaultValue)
  }

#endif
