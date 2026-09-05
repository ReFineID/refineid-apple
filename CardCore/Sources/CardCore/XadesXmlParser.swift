// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

import Foundation

/// SAX parser for XAdES signature elements within META-INF signature files.
internal final class XadesXmlParser: NSObject, XMLParserDelegate {
  private let xmlString: String
  private var signatures: [AsicVerification.ParsedSignature] = []
  private var currentSignature: AsicVerification.ParsedSignature?

  private var elementStack: [String] = []
  private var currentCharacters = ""

  private var currentRefIdentifier: String?
  private var currentRefUri: String?
  private var currentRefType: String?
  private var currentRefDigestMethod: String?
  private var currentRefDigestValue: Data?

  internal init(xmlString: String) {
    self.xmlString = xmlString
    super.init()
  }

  internal func parse(data: Data) -> [AsicVerification.ParsedSignature] {
    let parser = XMLParser(data: data)
    parser.delegate = self
    parser.parse()
    return signatures
  }

  internal func parser(
    _: XMLParser,
    didStartElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?,
    attributes attributeDict: [String: String]
  ) {
    let localName = elementName.components(separatedBy: ":").last ?? elementName
    elementStack.append(localName)
    currentCharacters = ""

    handleStartElement(localName: localName, elementName: elementName, attributeDict: attributeDict)
  }

  private func handleStartElement(
    localName: String,
    elementName: String,
    attributeDict: [String: String]
  ) {
    if localName == "Signature" {
      currentSignature = AsicVerification.ParsedSignature()
    } else if localName == "SignedInfo" {
      currentSignature?.signedInfoRawXml = extractElementSlice(tag: elementName, in: xmlString)
    } else if localName == "CanonicalizationMethod" {
      currentSignature?.canonicalizationMethod = attributeDict["Algorithm"]
    } else if localName == "SignatureMethod" {
      currentSignature?.signatureMethod = attributeDict["Algorithm"]
    } else if localName == "Reference" {
      currentRefIdentifier = attributeDict["Id"]
      currentRefUri = attributeDict["URI"]
      currentRefType = attributeDict["Type"]
      currentRefDigestMethod = nil
      currentRefDigestValue = nil
    } else if localName == "DigestMethod" {
      currentRefDigestMethod = attributeDict["Algorithm"]
    } else if localName == "SignatureValue" {
      currentSignature?.signatureValueId = attributeDict["Id"]
      currentSignature?.signatureValueRawXml = extractElementSlice(tag: elementName, in: xmlString)
    } else if localName == "SignedProperties" {
      currentSignature?.signedPropertiesId = attributeDict["Id"]
      currentSignature?.signedPropertiesRawXml = extractElementSlice(
        tag: elementName, in: xmlString)
    }
  }

  internal func parser(_: XMLParser, foundCharacters string: String) {
    currentCharacters += string
  }

  internal func parser(
    _: XMLParser,
    didEndElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?
  ) {
    let localName = elementName.components(separatedBy: ":").last ?? elementName
    let trimmed = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)

    handleEndElement(localName: localName, trimmed: trimmed)

    if !elementStack.isEmpty {
      elementStack.removeLast()
    }
    currentCharacters = ""
  }

  private func handleEndElement(localName: String, trimmed: String) {
    if localName == "DigestValue" {
      currentRefDigestValue = Data(base64Encoded: trimmed)
    } else if localName == "Reference" {
      appendCurrentReference()
    } else if localName == "SignatureValue" {
      currentSignature?.signatureValueBytes = Data(base64Encoded: trimmed)
    } else if localName == "X509Certificate" {
      if currentSignature?.signerCertificateDer == nil, elementStack.contains("KeyInfo") {
        currentSignature?.signerCertificateDer = Data(base64Encoded: trimmed)
      }
    } else if localName == "EncapsulatedTimeStamp" {
      if let token = Data(base64Encoded: trimmed) {
        currentSignature?.timestampTokens.append(token)
      }
    } else if localName == "Signature" {
      if let finished = currentSignature {
        signatures.append(finished)
      }
      currentSignature = nil
    }
  }

  private func appendCurrentReference() {
    guard let uri = currentRefUri,
      let digestMethod = currentRefDigestMethod,
      let digestValue = currentRefDigestValue
    else {
      return
    }
    currentSignature?.references.append(
      AsicVerification.ParsedReference(
        identifier: currentRefIdentifier,
        uri: uri,
        type: currentRefType,
        digestMethod: digestMethod,
        digestValue: digestValue
      )
    )
  }

  private func extractElementSlice(tag: String, in xml: String) -> String? {
    let startOpen = "<\(tag)"
    guard let startRange = xml.range(of: startOpen) else { return nil }
    let endTag = "</\(tag)>"
    guard let endRange = xml.range(of: endTag, range: startRange.lowerBound..<xml.endIndex) else {
      return nil
    }
    return String(xml[startRange.lowerBound..<endRange.upperBound])
  }
}
