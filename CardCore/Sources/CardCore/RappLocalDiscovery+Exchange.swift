// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if canImport(Network) && canImport(RappEngine)
  import Foundation
  import Network
  import RappEngine

  // MARK: - Direct TCP Exchange

  extension RappLocalDiscovery {
    internal func connectAndExchange(endpoint: NWEndpoint) {
      let parameters = NWParameters.tcp
      parameters.includePeerToPeer = true
      let connection = NWConnection(to: endpoint, using: parameters)

      connection.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        switch state {
        case .ready:
          let localRecord = makeLocalRecord()
          sendRecord(localRecord, over: connection)
          readRecord(from: connection) { [weak self] peerRecord in
            connection.cancel()
            guard let self, let peerRecord, peerRecord.deviceID != localIdentity.deviceID
            else { return }
            onDiscovered(peerRecord)
          }
        case .failed, .cancelled:
          connection.cancel()
        default:
          break
        }
      }

      connection.start(queue: queue)
    }

    internal func handleIncomingDiscovery(_ connection: NWConnection) {
      connection.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        switch state {
        case .ready:
          let localRecord = makeLocalRecord()
          sendRecord(localRecord, over: connection)
          readRecord(from: connection) { [weak self] peerRecord in
            connection.cancel()
            guard let self, let peerRecord, peerRecord.deviceID != localIdentity.deviceID
            else { return }
            onDiscovered(peerRecord)
          }
        case .failed, .cancelled:
          connection.cancel()
        default:
          break
        }
      }

      connection.start(queue: queue)
    }

    private func makeLocalRecord() -> RappCloudDeviceRecord {
      RappCloudDeviceRecord(
        deviceID: localIdentity.deviceID,
        deviceName: localIdentity.deviceName,
        modelName: localIdentity.modelName,
        role: localRole,
        staticPublicKey: localIdentity.publicKeyData,
        rendezvousToken: RappSameAccountPairBuilder.deriveRendezvousToken(
          publicKeyA: localIdentity.publicKeyData,
          publicKeyB: localIdentity.publicKeyData
        ),
        updatedAt: Date()
      )
    }

    private func sendRecord(_ record: RappCloudDeviceRecord, over connection: NWConnection) {
      guard let json = try? JSONEncoder().encode(record) else { return }
      var payload = Data()
      var length = UInt32(json.count).bigEndian
      payload.append(Data(bytes: &length, count: Constants.lengthHeaderByteCount))
      payload.append(json)
      connection.send(
        content: payload,
        completion: .contentProcessed { _ in
          // Transmission processed
        })
    }

    private func readRecord(
      from connection: NWConnection,
      completion: @escaping @Sendable (RappCloudDeviceRecord?) -> Void
    ) {
      connection.receive(
        minimumIncompleteLength: Constants.lengthHeaderByteCount,
        maximumLength: Constants.lengthHeaderByteCount
      ) { headerData, _, _, error in
        guard error == nil, let headerData, headerData.count == Constants.lengthHeaderByteCount
        else {
          completion(nil)
          return
        }
        let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard length > 0, length <= Constants.maxPayloadByteCount else {
          completion(nil)
          return
        }
        connection.receive(
          minimumIncompleteLength: Int(length),
          maximumLength: Int(length)
        ) { bodyData, _, _, _ in
          guard let bodyData, bodyData.count == Int(length) else {
            completion(nil)
            return
          }
          let record = try? JSONDecoder().decode(RappCloudDeviceRecord.self, from: bodyData)
          completion(record)
        }
      }
    }
  }

#endif
