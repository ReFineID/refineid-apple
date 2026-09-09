// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

internal enum RappSessionConformanceCorpusSupport {
  private enum Constants {
    static let hexPairCharacters = 2
    static let hexRadix = 16
  }

  internal struct SessionCorpus: Decodable {
    internal let sequenceGuard: [SequenceVector]
    internal let wireVersion: [WireVersionVector]
    internal let grantEnforcement: [GrantVector]
  }

  internal struct SequenceVector: Decodable {
    internal let name: String
    internal let guardSessionIdHex: String
    internal let acceptedSequences: [UInt64]
    internal let incomingSessionIdHex: String
    internal let incomingSequence: UInt64
    internal let expected: String
    internal let expectedNextReceive: UInt64
  }

  internal struct WireVersionVector: Decodable {
    internal let name: String
    internal let version: [UInt16]
    internal let expected: String
  }

  internal struct GrantVector: Decodable {
    internal let name: String
    internal let grantedProfiles: [String]
    internal let requestedProfile: String
    internal let expected: String
  }

  internal enum IndependentSequenceDecision: String {
    case accepted = "accepted"
    case wrongSequence = "wrong_sequence"
    case wrongSession = "wrong_session"
  }

  internal struct IndependentSequenceGuard {
    // MARK: Properties

    internal let sessionID: Data
    internal private(set) var nextReceive: UInt64 = 0

    // MARK: Functions

    internal mutating func accept(
      sessionID incomingSessionID: Data,
      sequence: UInt64
    ) -> IndependentSequenceDecision {
      guard incomingSessionID == sessionID else { return .wrongSession }
      guard sequence == nextReceive else { return .wrongSequence }
      guard nextReceive < UInt64.max else { return .wrongSequence }
      nextReceive += 1
      return .accepted
    }
  }

  internal enum SessionCorpusError: Error {
    case invalidHex
  }

  internal static func data(fromHex value: String) throws -> Data {
    let characters = Array(value.utf8)
    guard
      characters.count.isMultiple(of: Constants.hexPairCharacters),
      value.count.isMultiple(of: Constants.hexPairCharacters)
    else {
      throw SessionCorpusError.invalidHex
    }
    var result = Data()
    result.reserveCapacity(characters.count / Constants.hexPairCharacters)
    var index = value.startIndex
    while index < value.endIndex {
      let next = value.index(index, offsetBy: Constants.hexPairCharacters)
      guard
        let byte = UInt8(value[index..<next], radix: Constants.hexRadix)
      else {
        throw SessionCorpusError.invalidHex
      }
      result.append(byte)
      index = next
    }
    return result
  }
}
