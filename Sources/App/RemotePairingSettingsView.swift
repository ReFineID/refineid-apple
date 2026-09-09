// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)

  import CardCore
  import RappEngine
  import SwiftUI

  /// The Settings pane for managing paired devices and automatic connections.
  internal struct RemotePairingSettingsView: View {
    private enum Layout {
      static let rowSpacing: CGFloat = 6
      static let refreshIntervalSeconds: TimeInterval = 3
    }

    private struct DisplayedDevice {
      let identifier: String
      let name: String
      let modelName: String?
      let isPreferred: Bool
      let isOnline: Bool
      let isConnected: Bool
      let onDelete: () -> Void
      let onSetPreferred: () -> Void
    }

    @AppStorage("fi.refineid.preferredRemoteDeviceID")
    private var preferredDeviceID: String = ""

    @StateObject private var model = RappPairingModel()
    @State private var remoteDevices: [RappCloudDeviceRecord] = []

    internal var body: some View {
      Form {
        remoteDevicesSection
      }
      .formStyle(.grouped)
      .onAppear {
        reload()
        RappAutoPairingService.shared.reconcile()
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: RappAutoPairingService.pairingsDidChangeNotification
        )
      ) { _ in
        reload()
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: RappPairingModel.pairingsDidChangeNotification
        )
      ) { _ in
        reload()
      }
      .onReceive(
        NotificationCenter.default.publisher(
          for: NSApplication.didBecomeActiveNotification
        )
      ) { _ in
        reload()
      }
      .onReceive(
        Timer.publish(every: Layout.refreshIntervalSeconds, on: .main, in: .common).autoconnect()
      ) { _ in
        reload()
      }
    }

    private var displayedDevices: [DisplayedDevice] {
      let validRemoteDevices = remoteDevices.filter { device in
        device.role == .holder
      }

      let localPublicKey = RappAutoPairingService.shared.localIdentity?.publicKeyData

      let derivedRemotePairIDs: Set<Data> = Set(
        validRemoteDevices.compactMap { device in
          guard let localPublicKey else { return nil }
          return RappSameAccountPairBuilder.derivePairIdentifier(
            publicKeyA: localPublicKey,
            publicKeyB: device.staticPublicKey
          )
        }
      )

      let validExtraPairs = model.pairs.filter { pair in
        guard pair.role == .requester else { return false }
        guard !derivedRemotePairIDs.contains(pair.pairID) else { return false }
        let pairName = RappPairNames.name(forPairID: pair.pairID) ?? ""
        return !validRemoteDevices.contains { remote in
          remote.deviceName.caseInsensitiveCompare(pairName) == .orderedSame
            || remote.modelName.caseInsensitiveCompare(pairName) == .orderedSame
        }
      }

      var seenExtraNames = Set<String>()
      let deduplicatedExtraPairs = validExtraPairs.filter { pair in
        let name = (RappPairNames.name(forPairID: pair.pairID) ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        guard !name.isEmpty else { return false }
        return seenExtraNames.insert(name).inserted
      }

      let totalCount = validRemoteDevices.count + deduplicatedExtraPairs.count
      let effectivePreferredID =
        preferredDeviceID.isEmpty && totalCount == 1
        ? (validRemoteDevices.first?.deviceID.uuidString
          ?? deduplicatedExtraPairs.first?.pairID.base64EncodedString() ?? "")
        : preferredDeviceID

      let activePairID = PersistentTokenRegistry.activePairID

      var list: [DisplayedDevice] = []

      for device in validRemoteDevices {
        let idStr = device.deviceID.uuidString
        let isPreferred = idStr == effectivePreferredID

        let derivedPairID: Data?
        if let localPublicKey {
          derivedPairID = RappSameAccountPairBuilder.derivePairIdentifier(
            publicKeyA: localPublicKey,
            publicKeyB: device.staticPublicKey
          )
        } else {
          derivedPairID = nil
        }

        let isCurrentPair: Bool
        if let derivedPairID, let activePairID {
          isCurrentPair = (derivedPairID == activePairID)
        } else {
          isCurrentPair = isPreferred
        }

        let isOnline =
          RappAutoPairingService.shared.isDeviceOnline(
            deviceID: device.deviceID,
            deviceName: device.deviceName
          ) || (isCurrentPair && PersistentTokenRegistry.shared.holderIsAdvertising)
        let isConnected =
          isCurrentPair
          && isOnline
          && PersistentTokenRegistry.shared.holderIsAdvertising
          && PersistentTokenRegistry.shared.certificateDER != nil

        list.append(
          DisplayedDevice(
            identifier: idStr,
            name: device.deviceName,
            modelName: device.modelName,
            isPreferred: isPreferred,
            isOnline: isOnline,
            isConnected: isConnected,
            onDelete: {
              if isPreferred { preferredDeviceID = "" }
              RappAutoPairingService.shared.removeRemoteDevice(deviceID: device.deviceID)
              if let derivedPairID {
                model.revoke(pairID: derivedPairID)
              }
              reload()
            },
            onSetPreferred: {
              preferredDeviceID = idStr
              if let derivedPairID {
                model.select(pairID: derivedPairID)
              }
              PersistentTokenRegistry.shared.restartWatchingPresence()
            }
          )
        )
      }

      for pair in deduplicatedExtraPairs {
        let idStr = pair.pairID.base64EncodedString()
        let pairName = RappPairNames.name(forPairID: pair.pairID) ?? ""
        let isPreferred =
          idStr == effectivePreferredID
          || (model.selectedPairID == pair.pairID)

        let isCurrentPair: Bool
        if let activePairID {
          isCurrentPair = (pair.pairID == activePairID)
        } else {
          isCurrentPair = isPreferred
        }

        let isOnline =
          RappAutoPairingService.shared.isDeviceOnline(
            deviceID: nil,
            deviceName: pairName
          ) || (isCurrentPair && PersistentTokenRegistry.shared.holderIsAdvertising)
        let isConnected =
          isCurrentPair
          && isOnline
          && PersistentTokenRegistry.shared.holderIsAdvertising
          && PersistentTokenRegistry.shared.certificateDER != nil

        list.append(
          DisplayedDevice(
            identifier: idStr,
            name: pairName,
            modelName: nil,
            isPreferred: isPreferred,
            isOnline: isOnline,
            isConnected: isConnected,
            onDelete: {
              if isPreferred { preferredDeviceID = "" }
              model.revoke(pairID: pair.pairID)
              for remote in validRemoteDevices
              where remote.deviceName.caseInsensitiveCompare(pairName) == .orderedSame {
                RappAutoPairingService.shared.removeRemoteDevice(deviceID: remote.deviceID)
              }
              reload()
            },
            onSetPreferred: {
              preferredDeviceID = idStr
              model.select(pairID: pair.pairID)
              PersistentTokenRegistry.shared.restartWatchingPresence()
            }
          )
        )
      }

      return list.sorted { lhs, rhs in
        if lhs.isPreferred != rhs.isPreferred {
          return lhs.isPreferred && !rhs.isPreferred
        }
        if lhs.isConnected != rhs.isConnected {
          return lhs.isConnected && !rhs.isConnected
        }
        if lhs.isOnline != rhs.isOnline {
          return lhs.isOnline && !rhs.isOnline
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }
    }

    private var remoteDevicesSection: some View {
      let devices = displayedDevices
      return Section {
        if devices.isEmpty {
          Text("Ei liitettyjä laitteita")
            .foregroundStyle(.secondary)
        } else {
          ForEach(devices, id: \.identifier) { device in
            RemoteDeviceRow(
              name: device.name,
              modelName: device.modelName,
              isOnline: device.isOnline,
              isConnected: device.isConnected,
              onDelete: device.onDelete
            )
          }
        }
      } header: {
        Text("Etälaitteet")
      } footer: {
        if !devices.isEmpty {
          HStack {
            Spacer()
            Button("Poista kaikki etälaitteet", role: .destructive) {
              preferredDeviceID = ""
              RappAutoPairingService.shared.clearAllRemoteDevices()
              model.revokeAll()
              reload()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.red)
          }
          .padding(.top, Layout.rowSpacing)
        }
      }
    }

    private func reload() {
      model.refresh()
      remoteDevices = RappAutoPairingService.shared.remoteDevices
    }
  }

#endif
