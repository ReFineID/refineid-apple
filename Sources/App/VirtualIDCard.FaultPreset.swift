// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(iOS)

  import CardCore

  extension VirtualIDCard.FaultPreset {
    internal var localizedName: String {
      VirtualIDCardOverlayLocalization.faultPresetName(self)
    }
  }

#endif
