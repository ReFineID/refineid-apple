// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

extension OcspResponse {
  /// Calendar components decoded from one UTC GeneralizedTime value.
  private struct GeneralizedTimeFields {
    /// Day of month.
    let day: Int

    /// Hour of day.
    let hour: Int

    /// Minute of hour.
    let minute: Int

    /// Month of year.
    let month: Int

    /// Second of minute.
    let second: Int

    /// Four-digit Gregorian year.
    let year: Int
  }

  /// Parses the RFC 5280 GeneralizedTime profile used by OCSP.
  internal static func generalizedTime(
    in encoded: Data,
    element: DerReader.Element
  ) throws -> Date {
    guard element.tag == DerValues.tagGeneralizedTime else {
      throw ValidationFailure.malformed
    }
    let bytes = DerReader(encoded).contentData(of: element)
    guard Self.isUtcGeneralizedTime(bytes) else {
      throw ValidationFailure.malformed
    }
    return try Self.utcDate(from: Self.generalizedTimeFields(in: bytes))
  }

  /// Confirms the UTC-only GeneralizedTime wire shape before slicing it.
  private static func isUtcGeneralizedTime(_ bytes: Data) -> Bool {
    bytes.count == TimeLayout.totalLength
      && bytes.last == DerValues.asciiZulu
      && bytes.dropLast(TimeLayout.suffixLength).allSatisfy { byte in
        byte >= DerValues.asciiZero && byte <= DerValues.asciiNine
      }
  }

  /// Extracts each decimal calendar component from a validated wire value.
  private static func generalizedTimeFields(
    in bytes: Data
  ) throws -> GeneralizedTimeFields {
    let day = try Self.decimal(Data(bytes[TimeLayout.day]))
    let hour = try Self.decimal(Data(bytes[TimeLayout.hour]))
    let minute = try Self.decimal(Data(bytes[TimeLayout.minute]))
    let month = try Self.decimal(Data(bytes[TimeLayout.month]))
    let second = try Self.decimal(Data(bytes[TimeLayout.second]))
    let year = try Self.decimal(Data(bytes[TimeLayout.year]))
    guard year > 0 else { throw ValidationFailure.malformed }
    return GeneralizedTimeFields(
      day: day,
      hour: hour,
      minute: minute,
      month: month,
      second: second,
      year: year
    )
  }

  /// Builds a UTC date while rejecting values Calendar would normalize.
  private static func utcDate(
    from fields: GeneralizedTimeFields
  ) throws -> Date {
    guard let utc = TimeZone(secondsFromGMT: TimeLayout.utcOffsetSeconds) else {
      throw ValidationFailure.malformed
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = utc
    let components = DateComponents(
      calendar: calendar,
      timeZone: utc,
      year: fields.year,
      month: fields.month,
      day: fields.day,
      hour: fields.hour,
      minute: fields.minute,
      second: fields.second
    )
    guard let date = calendar.date(from: components) else {
      throw ValidationFailure.malformed
    }
    let checked = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: date
    )
    guard
      checked.year == fields.year,
      checked.month == fields.month,
      checked.day == fields.day,
      checked.hour == fields.hour,
      checked.minute == fields.minute,
      checked.second == fields.second
    else {
      throw ValidationFailure.malformed
    }
    return date
  }

  /// Reads one decimal component without accepting non-ASCII digits.
  internal static func decimal(_ digits: Data) throws -> Int {
    var value = 0
    for digit in digits {
      guard
        digit >= DerValues.asciiZero,
        digit <= DerValues.asciiNine
      else {
        throw ValidationFailure.malformed
      }
      value = value * TimeLayout.radix + Int(digit - DerValues.asciiZero)
    }
    return value
  }

  /// Reads nextUpdate's explicit wrapper.
  internal static func explicitGeneralizedTime(
    in encoded: Data,
    wrapper: DerReader.Element
  ) throws -> Date {
    var reader = DerReader(encoded, within: wrapper)
    let time = try Self.requiredElement(
      from: &reader,
      tag: DerValues.tagGeneralizedTime
    )
    guard reader.isAtEnd else { throw ValidationFailure.malformed }
    return try Self.generalizedTime(in: encoded, element: time)
  }

  /// Rejects future or expired evidence before it can become LT material.
  internal static func checkTimes(
    _ response: ResponseData,
    against currentTime: Date
  ) throws {
    let latestPermitted = currentTime.addingTimeInterval(Self.maximumClockSkew)
    guard
      response.producedAt <= latestPermitted,
      response.thisUpdate <= latestPermitted
    else {
      throw ValidationFailure.responseFromFuture
    }
    guard response.thisUpdate <= response.producedAt.addingTimeInterval(Self.maximumClockSkew)
    else {
      throw ValidationFailure.responseFromFuture
    }
    if let nextUpdate = response.nextUpdate {
      guard
        nextUpdate > response.thisUpdate,
        nextUpdate > currentTime.addingTimeInterval(-Self.maximumClockSkew)
      else {
        throw ValidationFailure.responseExpired
      }
    } else {
      guard
        currentTime.timeIntervalSince(response.thisUpdate)
          <= Self.maximumAgeWithoutNextUpdate + Self.maximumClockSkew
      else {
        throw ValidationFailure.responseExpired
      }
    }
  }
}
