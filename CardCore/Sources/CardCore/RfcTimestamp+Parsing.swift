// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension RfcTimestamp {
  /// A parsed message imprint and the following binding fields.
  internal struct Binding {
    /// The complete AlgorithmIdentifier.
    internal let algorithm: Data

    /// The imprint OCTET STRING content.
    internal let digest: Data

    /// The generation time.
    internal let generatedAt: Date

    /// The complete nonce INTEGER, when present.
    internal let nonce: Data?
  }

  /// Required fields that precede TSTInfo's optional run.
  private struct RequiredFields {
    let generatedAt: Date
    let imprint: DerReader.Element
  }

  /// Progress through TSTInfo's ordered optional fields.
  private enum OptionalStage {
    case accuracy
    case extensions
    case nonce
    case ordering
    case start
    case tsa
  }

  /// Named positions in a YYYYMMDDHHMMSS GeneralizedTime.
  private enum TimeLayout {
    static let day = 6..<8
    static let digitCount = 14
    static let fractionDivisor: TimeInterval = 10
    static let fractionMarkerOffset = 14
    static let hour = 8..<10
    static let minute = 10..<12
    static let month = 4..<6
    static let radix = 10
    static let second = 12..<14
    static let suffixCount = 1
    static let year = 0..<4
  }

  /// The granted TimeStampToken element from a complete TimeStampResp.
  internal static func encodedToken(inResponse response: Data) throws -> Data {
    var outer = DerReader(response)
    guard
      let envelope = outer.next(),
      envelope.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    var reader = DerReader(response, within: envelope)
    guard
      let statusInfo = reader.next(),
      statusInfo.tag == DerValues.tagSequence
    else {
      throw TokenFailure.malformed
    }
    var statusReader = DerReader(response, within: statusInfo)
    guard
      let status = statusReader.next(),
      status.tag == DerValues.tagInteger,
      let statusValue = statusReader.integerValue(of: status)
    else {
      throw TokenFailure.malformed
    }
    guard SignOids.grantedStatuses.contains(statusValue) else {
      throw TokenFailure.rejected(status: statusValue)
    }
    guard
      let tokenElement = reader.next(),
      tokenElement.tag == DerValues.tagSequence,
      reader.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    return reader.data(of: tokenElement)
  }

  /// The binding fields out of a TSTInfo.
  internal static func binding(in tstInfo: Data) throws -> Binding {
    var outer = DerReader(tstInfo)
    guard
      let sequence = outer.next(),
      sequence.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    var reader = DerReader(tstInfo, within: sequence)
    let required = try Self.requiredFields(reader: &reader)
    var imprint = DerReader(tstInfo, within: required.imprint)
    guard
      let algorithm = imprint.next(),
      algorithm.tag == DerValues.tagSequence,
      let hashed = imprint.next(),
      hashed.tag == DerValues.tagOctetString,
      imprint.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    return Binding(
      algorithm: imprint.data(of: algorithm),
      digest: imprint.contentData(of: hashed),
      generatedAt: required.generatedAt,
      nonce: try Self.nonce(reader: &reader)
    )
  }

  /// The fixed TSTInfo prefix through genTime.
  private static func requiredFields(
    reader: inout DerReader
  ) throws -> RequiredFields {
    guard
      let version = reader.next(),
      version.tag == DerValues.tagInteger,
      reader.integerValue(of: version) == SignOids.tstInfoVersion,
      let policy = reader.next(),
      policy.tag == DerValues.tagObjectIdentifier,
      let imprint = reader.next(),
      imprint.tag == DerValues.tagSequence,
      let serial = reader.next(),
      serial.tag == DerValues.tagInteger,
      let time = reader.next(),
      time.tag == DerValues.tagGeneralizedTime,
      let generatedAt = Self.generalizedTime(reader.contentData(of: time))
    else {
      throw TokenFailure.malformed
    }
    return RequiredFields(generatedAt: generatedAt, imprint: imprint)
  }

  /// The nonce in TSTInfo's ordered optional-field run.
  private static func nonce(reader: inout DerReader) throws -> Data? {
    var found: Data?
    var stage = OptionalStage.start
    while let candidate = reader.next() {
      switch candidate.tag {
      case DerValues.tagSequence where stage == .start:
        stage = .accuracy

      case DerValues.tagBoolean where stage == .start || stage == .accuracy:
        stage = .ordering

      case DerValues.tagInteger
      where stage == .start || stage == .accuracy || stage == .ordering:
        found = reader.data(of: candidate)
        stage = .nonce

      case DerValues.tagContext0Constructed
      where stage != .tsa && stage != .extensions:
        stage = .tsa

      case DerValues.tagContext1Constructed where stage != .extensions:
        stage = .extensions

      default:
        throw TokenFailure.malformed
      }
    }
    guard reader.isAtEnd else { throw TokenFailure.malformed }
    return found
  }

  /// Whether an AlgorithmIdentifier is SHA-384 with absent or NULL
  /// parameters, both forms recipients must understand (RFC 5754).
  internal static func isSha384(_ encoded: Data) -> Bool {
    var outer = DerReader(encoded)
    guard
      let sequence = outer.next(),
      sequence.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      return false
    }
    var reader = DerReader(encoded, within: sequence)
    guard
      let oid = reader.next(),
      reader.data(of: oid) == DerEncoder.objectIdentifier(SignOids.sha384)
    else {
      return false
    }
    guard let parameters = reader.next() else { return reader.isAtEnd }
    return parameters.tag == DerValues.tagNull
      && reader.contentData(of: parameters).isEmpty
      && reader.isAtEnd
  }

  /// The TSTInfo eContent octets inside a token's SignedData.
  internal static func tstInfoContent(in token: Data) throws -> Data {
    let signedData = try Self.signedData(in: token)
    var signed = DerReader(token, within: signedData)
    guard
      signed.next() != nil,
      signed.next() != nil,
      let encapsulated = signed.next(),
      encapsulated.tag == DerValues.tagSequence
    else {
      throw TokenFailure.malformed
    }
    var info = DerReader(token, within: encapsulated)
    guard
      let contentType = info.next(),
      info.data(of: contentType) == DerEncoder.objectIdentifier(SignOids.tstInfo),
      let wrapper = info.next(),
      wrapper.tag == DerValues.tagContext0Constructed,
      info.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    var content = DerReader(token, within: wrapper)
    guard
      let octets = content.next(),
      octets.tag == DerValues.tagOctetString,
      content.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    return content.contentData(of: octets)
  }

  /// The SignedData element inside a CMS ContentInfo.
  private static func signedData(in token: Data) throws -> DerReader.Element {
    var outer = DerReader(token)
    guard
      let contentInfo = outer.next(),
      contentInfo.tag == DerValues.tagSequence,
      outer.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    var info = DerReader(token, within: contentInfo)
    guard
      let typeOid = info.next(),
      info.data(of: typeOid) == DerEncoder.objectIdentifier(SignOids.signedData),
      let wrapper = info.next(),
      wrapper.tag == DerValues.tagContext0Constructed,
      info.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    var wrapped = DerReader(token, within: wrapper)
    guard
      let signedData = wrapped.next(),
      signedData.tag == DerValues.tagSequence,
      wrapped.isAtEnd
    else {
      throw TokenFailure.malformed
    }
    return signedData
  }

  /// A DER GeneralizedTime in the UTC form RFC 3161 requires.
  private static func generalizedTime(_ encoded: Data) -> Date? {
    let bytes = Array(encoded)
    let minimum = TimeLayout.digitCount + TimeLayout.suffixCount
    guard bytes.count >= minimum, bytes.last == UInt8(ascii: "Z") else {
      return nil
    }
    guard
      let year = Self.decimal(bytes[TimeLayout.year]),
      let month = Self.decimal(bytes[TimeLayout.month]),
      let day = Self.decimal(bytes[TimeLayout.day]),
      let hour = Self.decimal(bytes[TimeLayout.hour]),
      let minute = Self.decimal(bytes[TimeLayout.minute]),
      let second = Self.decimal(bytes[TimeLayout.second])
    else {
      return nil
    }
    let components = DateComponents(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second
    )
    guard
      let date = Self.date(from: components),
      let fraction = Self.fraction(in: encoded)
    else {
      return nil
    }
    return date.addingTimeInterval(fraction)
  }

  /// The optional decimal fraction of one GeneralizedTime second.
  private static func fraction(in encoded: Data) -> TimeInterval? {
    let bytes = Array(encoded)
    let minimum = TimeLayout.digitCount + TimeLayout.suffixCount
    guard bytes.count > minimum else { return 0 }
    let first = TimeLayout.fractionMarkerOffset
    guard bytes[first] == UInt8(ascii: ".") else { return nil }
    let range = (first + TimeLayout.suffixCount)..<(bytes.count - TimeLayout.suffixCount)
    guard let value = Self.decimal(bytes[range]) else { return nil }
    let places = TimeInterval(range.count)
    return TimeInterval(value) / pow(TimeLayout.fractionDivisor, places)
  }

  /// A checked UTC calendar date.
  private static func date(from components: DateComponents) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    guard let date = calendar.date(from: components) else { return nil }
    let checked = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: date
    )
    return checked.year == components.year
      && checked.month == components.month
      && checked.day == components.day
      && checked.hour == components.hour
      && checked.minute == components.minute
      && checked.second == components.second ? date : nil
  }

  /// A run of ASCII decimal digits as an integer.
  private static func decimal(_ bytes: ArraySlice<UInt8>) -> Int? {
    guard !bytes.isEmpty else { return nil }
    var value = 0
    for byte in bytes {
      guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
        return nil
      }
      let digit = Int(byte - UInt8(ascii: "0"))
      guard value <= (Int.max - digit) / TimeLayout.radix else {
        return nil
      }
      value = value * TimeLayout.radix + digit
    }
    return value
  }
}
