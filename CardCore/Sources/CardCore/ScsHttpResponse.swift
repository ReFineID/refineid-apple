// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// Builders for the SCS's HTTP responses.
///
/// Every response carries the CORS headers the browser needs to hand
/// the answer to the calling page: the request's own Origin is echoed
/// (the SCS is same-machine, origin-bound by challenge rather than by
/// CORS allowlist), and the preflight answers 200 as the
/// specification's example shows (DVV SCS specification v1.3 §2.4).
/// Connections are single-use: every response closes.
public enum ScsHttpResponse {
  /// A JSON response with CORS headers.
  public static func json(status: Int, body: Data, origin: String?) -> Data {
    build(
      status: status,
      headers: corsHeaders(origin: origin) + [("Content-Type", "application/json")],
      body: body
    )
  }

  /// A compact JWT/JWE response with CORS headers.
  public static func jwt(_ compact: String, origin: String?) -> Data {
    build(
      status: ScsValues.httpOk,
      headers: corsHeaders(origin: origin) + [("Content-Type", "application/jwt")],
      body: Data(compact.utf8)
    )
  }

  /// A plain-text response with CORS headers.
  public static func text(status: Int, body: String, origin: String?) -> Data {
    build(
      status: status,
      headers: corsHeaders(origin: origin) + [("Content-Type", "text/plain; charset=utf-8")],
      body: Data(body.utf8)
    )
  }

  /// The CORS preflight acknowledgement.
  public static func preflight(origin: String?) -> Data {
    build(status: ScsValues.httpOk, headers: corsHeaders(origin: origin), body: Data())
  }

  private static func corsHeaders(origin: String?) -> [(String, String)] {
    [
      ("Access-Control-Allow-Origin", origin ?? "*"),
      ("Access-Control-Allow-Methods", "GET, POST"),
      ("Access-Control-Allow-Headers", "Accept, Content-Type"),
      ("Access-Control-Max-Age", "3600"),
      ("Vary", "Origin"),
    ]
  }

  private static func build(
    status: Int,
    headers: [(String, String)],
    body: Data
  ) -> Data {
    var head = "HTTP/1.1 \(status) \(reason(for: status))\r\n"
    head += "Content-Length: \(body.count)\r\n"
    head += "Connection: close\r\n"
    for (name, value) in headers {
      head += "\(name): \(value)\r\n"
    }
    head += "\r\n"
    var out = Data(head.utf8)
    out.append(body)
    return out
  }

  private static func reason(for status: Int) -> String {
    switch status {
    case ScsValues.httpOk:
      "OK"

    case ScsValues.httpNotFound:
      "Not Found"

    default:
      "Status"
    }
  }
}
