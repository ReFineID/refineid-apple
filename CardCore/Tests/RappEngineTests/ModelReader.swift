// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

@testable import RappEngine

/// Indentation levels of the block-style model document.
private let modelIndentSection = 2
private let modelIndentRule = 4
private let modelIndentRuleField = 6

/// A `key: value` line splits into exactly this many parts.
private let keyValueParts = 2
/// The `- ` that opens a rule.
private let ruleMarkerLength = 2

/// A deliberately small reader for the block-style subset the model uses.
internal struct ModelReader {
  internal let documentVersion: String
  internal let guardNames: Set<String>
  internal let actionNames: Set<String>
  internal let rules: [String: [ParsedRule]]

  internal init(text: String) {
    var parsedVersion = ""
    var parsedGuardNames: Set<String> = []
    var parsedActionNames: Set<String> = []
    var parsedRules: [String: [ParsedRule]] = ["pairing": [], "session": [], "operation": []]
    var section = ""
    var inTransitions = false
    var current: ParsedRule?

    func flush() {
      if let rule = current, !section.isEmpty, parsedRules[section] != nil {
        parsedRules[section]?.append(rule)
      }
      current = nil
    }

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = String(rawLine)
      if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") { continue }
      let body = Self.stripComment(line)
      if body.trimmingCharacters(in: .whitespaces).isEmpty { continue }
      let indent = body.prefix { $0 == " " }.count

      if indent == 0 {
        flush()
        inTransitions = false
        let name = body.split(separator: ":", maxSplits: 1)[0]
        section = String(name)
        if section == "document_version" {
          let quoted = CharacterSet(charactersIn: "\"")
          parsedVersion = Self.value(of: body).trimmingCharacters(in: quoted)
        }
        continue
      }

      if indent == modelIndentSection {
        flush()
        let key = body.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)[0]
        inTransitions = String(key) == "transitions"
        if !inTransitions {
          if section == "guards" { parsedGuardNames.insert(String(key)) }
          if section == "actions" { parsedActionNames.insert(String(key)) }
        }
        continue
      }

      guard inTransitions else { continue }
      let trimmed = body.trimmingCharacters(in: .whitespaces)
      if indent == modelIndentRule, trimmed.hasPrefix("- ") {
        flush()
        var rule = ParsedRule()
        Self.assign(String(trimmed.dropFirst(ruleMarkerLength)), into: &rule)
        current = rule
      } else if indent >= modelIndentRuleField, var rule = current {
        Self.assign(trimmed, into: &rule)
        current = rule
      }
    }
    flush()

    self.documentVersion = parsedVersion
    self.guardNames = parsedGuardNames
    self.actionNames = parsedActionNames
    self.rules = parsedRules
  }

  private static func stripComment(_ line: String) -> String {
    guard let range = line.range(of: " #") else { return line }
    return String(line[line.startIndex..<range.lowerBound])
  }

  private static func value(of line: String) -> String {
    let parts = line.split(separator: ":", maxSplits: 1)
    guard parts.count == keyValueParts else { return "" }
    return parts[1].trimmingCharacters(in: .whitespaces)
  }

  private static func scalarOrList(_ text: String) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return [trimmed] }
    let inner = trimmed.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
    if inner.isEmpty { return [] }
    return inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
  }

  private static func assign(_ text: String, into rule: inout ParsedRule) {
    let parts = text.split(separator: ":", maxSplits: 1)
    guard parts.count == keyValueParts else { return }
    let key = parts[0].trimmingCharacters(in: .whitespaces)
    let raw = parts[1].trimmingCharacters(in: .whitespaces)
    switch key {
    case "from":
      rule.from = scalarOrList(raw)

    case "event":
      rule.event = raw

    case "role":
      rule.role = raw

    case "guard":
      rule.condition = raw

    case "to":
      rule.destination = raw

    case "actions":
      rule.actions = scalarOrList(raw)

    default:
      break
    }
  }
}

internal func roles(of ruleRole: String) -> [EndpointRole] {
  switch ruleRole {
  case "requester":
    [.requester]

  case "proxy":
    [.proxy]

  default:
    [.requester, .proxy]
  }
}
