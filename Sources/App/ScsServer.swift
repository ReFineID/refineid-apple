// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#if os(macOS)
  import CardCore
  import Foundation
  import Network
  import Security

  /// The localhost SCS listener: TLS on 127.0.0.1:53952, one request
  /// per connection, dispatched to the CardCore protocol surface.
  ///
  /// `@unchecked Sendable` is the audit, not a shrug: the listener,
  /// every connection, and every dispatch run on the one serial
  /// queue below, so no state is touched concurrently. A sign blocks
  /// that queue while the holder answers the PIN prompt, which is
  /// the intended behaviour - the SCS serves one signature at a
  /// time.
  internal final class ScsServer: @unchecked Sendable {
    private static let readChunkLength = 65_536

    private let queue = DispatchQueue(label: "fi.refineid.scs.server")
    private let backend = ScsCardBackend()
    private let transactions = ScsTransactionManager()
    private var listener: NWListener?

    /// Binds and starts serving; failures are logged, never fatal
    /// to the app.
    internal func start() {
      guard let identity = ScsIdentityStore.obtain() else {
        ScsLog.error("server: no TLS identity; SCS not started")
        return
      }
      guard let secIdentity = sec_identity_create(identity) else {
        ScsLog.error("server: identity rejected by Network framework")
        return
      }
      let tls = NWProtocolTLS.Options()
      sec_protocol_options_set_local_identity(tls.securityProtocolOptions, secIdentity)
      let parameters = NWParameters(tls: tls)
      guard let port = NWEndpoint.Port(rawValue: ScsDispatcher.port) else {
        ScsLog.error("server: invalid port")
        return
      }
      parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
        host: NWEndpoint.Host("127.0.0.1"), port: port)
      let bound: NWListener
      do {
        bound = try NWListener(using: parameters)
      } catch {
        ScsLog.error("server: bind failed; another SCS already running?")
        return
      }
      bound.stateUpdateHandler = { state in
        switch state {
        case .ready:
          ScsLog.info("server: listening on https://127.0.0.1:\(ScsDispatcher.port)")

        case .failed:
          ScsLog.error("server: listener failed")

        default:
          break
        }
      }
      bound.newConnectionHandler = { [weak self] connection in
        guard let self else {
          connection.cancel()
          return
        }
        connection.start(queue: queue)
        receive(connection, buffered: Data())
      }
      listener = bound
      bound.start(queue: queue)
    }

    /// Accumulates one request's bytes and dispatches it when
    /// complete.
    private func receive(_ connection: NWConnection, buffered: Data) {
      connection.receive(
        minimumIncompleteLength: 1,
        maximumLength: Self.readChunkLength
      ) { [weak self] content, _, isComplete, error in
        guard let self else {
          connection.cancel()
          return
        }
        var buffer = buffered
        if let content {
          buffer.append(content)
        }
        switch ScsHttpAssembly.assemble(buffer: buffer) {
        case .complete(let exchange):
          respond(to: exchange, over: connection)

        case .invalid:
          connection.cancel()

        case .needMoreData:
          if error != nil || isComplete {
            connection.cancel()
          } else {
            receive(connection, buffered: buffer)
          }
        }
      }
    }

    /// Dispatches one assembled exchange and closes the connection
    /// after the answer, per the SCS's one-request connections.
    private func respond(to exchange: ScsHttpExchange, over connection: NWConnection) {
      ScsLog.info("server: \(exchange.request.method) \(exchange.request.path)")
      let response = ScsDispatcher.dispatch(
        request: exchange.request,
        body: exchange.body,
        backend: backend,
        transactions: transactions
      )
      connection.send(
        content: response,
        completion: .contentProcessed { _ in
          connection.cancel()
        }
      )
    }
  }
#endif
