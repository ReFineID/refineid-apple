// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

/// A deterministic identity card used by demonstrations and automated tests.
///
/// The virtual card models card state separately from device state. Card
/// mutations therefore change the same retry counters and factory flags that a
/// physical card changes, while setup changes only the simulated device. No
/// global switch lives in CardCore: a caller must explicitly construct and
/// retain an instance.
public actor VirtualIDCard {
  private var current: Snapshot

  private var activationRequired: Bool {
    current.card.pin1.isFactoryValue || current.card.pin2.isFactoryValue
  }

  private var activationEntryDigitCount: Int {
    switch current.card.generation {
    case .activationCodeIsPuk:
      Puk.maximumDigitCount

    case .presetActivationPIN:
      Puk.minimumDigitCount
    }
  }

  /// Creates a card preset to the given scenario.
  public init(scenario: Scenario = .factoryFreshNearField) {
    current = scenario.snapshot
  }

  /// Creates a card holding exactly the given snapshot.
  public init(snapshot: Snapshot) {
    current = snapshot
  }

  /// Reads the current snapshot without changing anything.
  public func inspect() -> Snapshot {
    current
  }

  /// Replaces the entire snapshot, queued faults included.
  public func replace(with snapshot: Snapshot) {
    current = snapshot
  }

  /// Discards all state and starts over from the scenario's snapshot.
  public func reset(to scenario: Scenario) {
    current = scenario.snapshot
  }

  /// Queues a fault to fire on its next matching operation.
  public func enqueue(_ fault: Fault) {
    current.faults.append(fault)
  }

  /// Discards every queued fault.
  public func clearFaults() {
    current.faults = []
  }

  /// Restores the simulated device to a fresh state, leaving the card as is.
  public func forgetDeviceState() {
    current.device = DeviceState()
  }

  /// Opens a connection, checking the CAN on the near-field transport.
  ///
  /// A successful near-field connection to an activated card also stores
  /// the CAN on the device.
  public func connect(cardAccessNumber: String) -> ConnectionResult {
    if let failure = reachabilityFailure() {
      current.device.connectedCardAccessNumber = nil
      return .unavailable(failure)
    }
    if let fault = consumeFault(for: .connect, phase: .beforeCommand) {
      current.device.connectedCardAccessNumber = nil
      return .unavailable(fault)
    }
    if current.card.transport == .nearField,
      !digitsAreValid(
        cardAccessNumber,
        within: CardAccessNumber.digitCount...CardAccessNumber.digitCount)
        || cardAccessNumber != current.card.cardAccessNumber
    {
      current.device.connectedCardAccessNumber = nil
      return .incorrectCardAccessNumber
    }
    current.device.connectedCardAccessNumber =
      current.card.transport == .nearField
      ? current.card.cardAccessNumber
      : nil
    if let fault = consumeFault(for: .connect, phase: .afterCardExecution) {
      current.device.connectedCardAccessNumber = nil
      return .unavailable(fault)
    }
    if current.card.transport == .nearField, !activationRequired {
      current.device.storedCardAccessNumber = current.card.cardAccessNumber
    }
    return .connected(current)
  }

  /// Reads the three retry counters without spending an attempt.
  public func probeCredentials() -> ProbeResult {
    if let failure = operationFailure() {
      return .unavailable(failure)
    }
    if let fault = consumeFault(for: .probeCredentials, phase: .beforeCommand) {
      return fault == .malformedResponse ? .unreadable : .unavailable(fault)
    }
    let report = RetryReport(
      pin1: current.card.pin1.attemptsRemaining,
      pin2: current.card.pin2.attemptsRemaining,
      puk: current.card.puk.attemptsRemaining)
    if let fault = consumeFault(
      for: .probeCredentials,
      phase: .afterCardExecution)
    {
      return fault == .malformedResponse ? .unreadable : .unavailable(fault)
    }
    return .report(report)
  }

  /// Changes PIN 1 after verifying the current PIN 1.
  public func changePIN1(current entered: String, new: String) -> MutationResult {
    change(
      role: .pin1,
      operation: .changePIN1,
      current: entered,
      new: new)
  }

  /// Changes PIN 2 after verifying the current PIN 2.
  public func changePIN2(current entered: String, new: String) -> MutationResult {
    change(
      role: .pin2,
      operation: .changePIN2,
      current: entered,
      new: new)
  }

  /// Sets a new PIN 1 after verifying the PUK.
  public func resetPIN1(puk: String, new: String) -> MutationResult {
    reset(role: .pin1, operation: .resetPIN1, puk: puk, new: new)
  }

  /// Sets a new PIN 2 after verifying the PUK.
  public func resetPIN2(puk: String, new: String) -> MutationResult {
    reset(role: .pin2, operation: .resetPIN2, puk: puk, new: new)
  }

  /// Activates factory PINs using the card's activation entry.
  ///
  /// PIN 1 is activated first and PIN 2 only after PIN 1 succeeds; on
  /// legacy cards the PUK's retry counter guards the entry.
  public func activate(_ request: ActivationRequest) -> ActivationResult {
    let needsPIN1 = current.card.pin1.isFactoryValue
    let needsPIN2 = current.card.pin2.isFactoryValue
    if let rejection = activationRejection(
      for: request, needsPIN1: needsPIN1, needsPIN2: needsPIN2)
    {
      return rejection
    }

    var pin1Outcome: CredentialOutcome = .alreadyActivated
    if needsPIN1, let newPIN1 = request.newPIN1 {
      pin1Outcome = activateCredential(
        role: .pin1,
        operation: .activatePIN1,
        entry: request.entry,
        new: newPIN1)
      guard pin1Outcome == .success else {
        return ActivationResult(
          pin1: pin1Outcome,
          pin2: nil,
          snapshot: current)
      }
    }

    var pin2Outcome: CredentialOutcome? = .alreadyActivated
    if needsPIN2, let newPIN2 = request.newPIN2 {
      pin2Outcome = activateCredential(
        role: .pin2,
        operation: .activatePIN2,
        entry: request.entry,
        new: newPIN2)
    }
    let pin1Completed =
      pin1Outcome == .success
      || pin1Outcome == .alreadyActivated
    let pin2Completed =
      pin2Outcome.map { outcome in
        outcome == .success || outcome == .alreadyActivated
      } ?? true
    if current.card.transport == .nearField,
      !activationRequired,
      pin1Completed,
      pin2Completed
    {
      current.device.storedCardAccessNumber =
        current.device.connectedCardAccessNumber
        ?? current.card.cardAccessNumber
    }
    return ActivationResult(
      pin1: pin1Outcome,
      pin2: pin2Outcome,
      snapshot: current)
  }

  /// The result an activation request earns before any credential changes,
  /// or nil when the request is well formed enough to attempt.
  private func activationRejection(
    for request: ActivationRequest,
    needsPIN1: Bool,
    needsPIN2: Bool
  ) -> ActivationResult? {
    guard needsPIN1 || needsPIN2 else {
      return ActivationResult(
        pin1: .alreadyActivated,
        pin2: nil,
        snapshot: current)
    }
    guard
      digitsAreValid(
        request.entry,
        within: activationEntryDigitCount...activationEntryDigitCount)
    else {
      return ActivationResult(
        pin1: .invalidEntry,
        pin2: nil,
        snapshot: current)
    }
    if needsPIN1,
      request.newPIN1.map({ credentialIsValid($0, for: .pin1) }) != true
    {
      return ActivationResult(
        pin1: .invalidEntry,
        pin2: nil,
        snapshot: current)
    }
    if needsPIN2,
      request.newPIN2.map({ credentialIsValid($0, for: .pin2) }) != true
    {
      return ActivationResult(
        pin1: needsPIN1 ? .invalidEntry : .alreadyActivated,
        pin2: .invalidEntry,
        snapshot: current)
    }
    return nil
  }

  /// Authenticates with PIN 1 and registers the card's token on the device.
  public func authenticate(pin1: String) -> AuthenticationResult {
    guard credentialIsValid(pin1, for: .pin1) else { return .invalidEntry }
    if let failure = operationFailure() {
      return .transportFailure(failure)
    }
    if let fault = consumeFault(for: .authenticate, phase: .beforeCommand) {
      return .transportFailure(fault)
    }
    guard current.card.authenticationCertificate == .valid else {
      return .certificateUnavailable
    }
    if let refusal = retryRefusal(current.card.pin1.attemptsRemaining) {
      return authenticationResult(from: refusal)
    }
    if pin1 != current.card.pin1.value {
      current.card.pin1.attemptsRemaining -= 1
      let remaining = current.card.pin1.attemptsRemaining
      return remaining == 0 ? .blocked : .rejected(remaining: remaining)
    }
    current.card.pin1.attemptsRemaining = RetryCount.pristineAllowance
    if let fault = consumeFault(for: .authenticate, phase: .afterCardExecution) {
      if fault == .tokenNotPublished {
        current.device.hasPin1 = true
        current.device.cachedIdentity = true
        current.device.tokenRegistered = false
        return .tokenPublicationFailed(current)
      }
      return .transportFailure(fault)
    }
    current.device.storedCardAccessNumber =
      current.device.connectedCardAccessNumber
      ?? current.device.storedCardAccessNumber
      ?? current.card.cardAccessNumber
    current.device.hasPin1 = true
    current.device.cachedIdentity = true
    current.device.tokenRegistered = true
    return .success(current)
  }

  /// Authorizes one virtual qualified signature with the same retry floor
  /// and state transitions as the physical card boundary.
  public func authorizeQualifiedSignature(pin2: String) -> SignatureResult {
    current.device.pendingSigningRequest = true
    guard credentialIsValid(pin2, for: .pin2) else {
      return finishSignature(.invalidEntry)
    }
    if let failure = operationFailure() {
      return finishSignature(.transportFailure(failure))
    }
    if let fault = consumeFault(
      for: .qualifiedSignature,
      phase: .beforeCommand)
    {
      return finishSignature(.transportFailure(fault))
    }
    guard current.card.signatureCertificate == .valid else {
      return finishSignature(.certificateUnavailable)
    }
    switch current.card.pin2.attemptsRemaining {
    case 0:
      return finishSignature(.blocked)

    case 1...RetryCount.lowAttemptCeiling:
      return finishSignature(
        .refusedLowAttempts(remaining: current.card.pin2.attemptsRemaining))

    default:
      break
    }
    if pin2 != current.card.pin2.value {
      current.card.pin2.attemptsRemaining -= 1
      let remaining = current.card.pin2.attemptsRemaining
      return finishSignature(
        remaining == 0 ? .blocked : .rejected(remaining: remaining))
    }
    current.card.pin2.attemptsRemaining = RetryCount.pristineAllowance
    if let fault = consumeFault(
      for: .qualifiedSignature,
      phase: .afterCardExecution)
    {
      return finishSignature(.transportFailure(fault))
    }
    return finishSignature(.success)
  }

  private func finishSignature(_ result: SignatureResult) -> SignatureResult {
    current.device.pendingSigningRequest = false
    return result
  }

  private func reachabilityFailure() -> FaultEffect? {
    guard current.card.cardPresent else { return .cardRemoved }
    if current.card.transport == .reader, !current.card.readerConnected {
      return .readerDisconnected
    }
    return nil
  }

  private func operationFailure() -> FaultEffect? {
    if let failure = reachabilityFailure() {
      return failure
    }
    if current.card.transport == .nearField {
      let offered =
        current.device.connectedCardAccessNumber
        ?? current.device.storedCardAccessNumber
      guard offered == current.card.cardAccessNumber else {
        return .connectionLost
      }
    }
    return nil
  }

  private func change(
    role: CredentialRole,
    operation: Operation,
    current entered: String,
    new: String
  ) -> MutationResult {
    guard credentialIsValid(entered, for: role),
      credentialIsValid(new, for: role),
      entered != new
    else {
      return MutationResult(outcome: .invalidEntry, snapshot: current)
    }
    if let failure = operationFailure() {
      return MutationResult(
        outcome: .transportFailure(failure),
        snapshot: current)
    }
    if let fault = consumeFault(for: operation, phase: .beforeCommand) {
      return MutationResult(
        outcome: .transportFailure(fault),
        snapshot: current)
    }
    var credential = credential(for: role)
    if let refusal = retryRefusal(credential.attemptsRemaining) {
      return MutationResult(outcome: refusal, snapshot: current)
    }
    let outcome: CredentialOutcome
    if entered != credential.value {
      credential.attemptsRemaining -= 1
      setCredential(credential, for: role)
      outcome =
        credential.attemptsRemaining == 0
        ? .blocked
        : .rejected(remaining: credential.attemptsRemaining)
    } else {
      credential.value = new
      credential.attemptsRemaining = RetryCount.pristineAllowance
      credential.isFactoryValue = false
      setCredential(credential, for: role)
      outcome = .success
    }
    if let fault = consumeFault(for: operation, phase: .afterCardExecution) {
      return MutationResult(
        outcome: .transportFailure(fault),
        snapshot: current)
    }
    return MutationResult(outcome: outcome, snapshot: current)
  }

  private func reset(
    role: CredentialRole,
    operation: Operation,
    puk enteredPUK: String,
    new: String
  ) -> MutationResult {
    guard
      digitsAreValid(
        enteredPUK,
        within: Puk.minimumDigitCount...Puk.maximumDigitCount),
      credentialIsValid(new, for: role)
    else {
      return MutationResult(outcome: .invalidEntry, snapshot: current)
    }
    if let failure = operationFailure() {
      return MutationResult(
        outcome: .transportFailure(failure),
        snapshot: current)
    }
    if let fault = consumeFault(for: operation, phase: .beforeCommand) {
      return MutationResult(
        outcome: .transportFailure(fault),
        snapshot: current)
    }
    if let refusal = retryRefusal(current.card.puk.attemptsRemaining) {
      return MutationResult(outcome: refusal, snapshot: current)
    }
    let outcome: CredentialOutcome
    if enteredPUK != current.card.puk.value {
      current.card.puk.attemptsRemaining -= 1
      outcome =
        current.card.puk.attemptsRemaining == 0
        ? .blocked
        : .rejected(remaining: current.card.puk.attemptsRemaining)
    } else {
      var target = credential(for: role)
      target.value = new
      target.attemptsRemaining = RetryCount.pristineAllowance
      target.isFactoryValue = false
      setCredential(target, for: role)
      current.card.puk.attemptsRemaining = RetryCount.pristineAllowance
      outcome = .success
    }
    if let fault = consumeFault(for: operation, phase: .afterCardExecution) {
      return MutationResult(
        outcome: .transportFailure(fault),
        snapshot: current)
    }
    return MutationResult(outcome: outcome, snapshot: current)
  }

  private func activateCredential(
    role: CredentialRole,
    operation: Operation,
    entry: String,
    new: String
  ) -> CredentialOutcome {
    if let failure = operationFailure() {
      return .transportFailure(failure)
    }
    if let fault = consumeFault(for: operation, phase: .beforeCommand) {
      return .transportFailure(fault)
    }
    let checkedRole: CredentialRole =
      current.card.generation == .activationCodeIsPuk ? .puk : role
    var checked = credential(for: checkedRole)
    if let refusal = retryRefusal(checked.attemptsRemaining) {
      return refusal
    }
    if entry != current.card.activationEntry {
      checked.attemptsRemaining -= 1
      setCredential(checked, for: checkedRole)
      return checked.attemptsRemaining == 0
        ? .blocked
        : .rejected(remaining: checked.attemptsRemaining)
    }
    var target = credential(for: role)
    target.value = new
    target.attemptsRemaining = RetryCount.pristineAllowance
    target.isFactoryValue = false
    setCredential(target, for: role)
    if checkedRole == .puk {
      current.card.puk.attemptsRemaining = RetryCount.pristineAllowance
    }
    if let fault = consumeFault(for: operation, phase: .afterCardExecution) {
      return .transportFailure(fault)
    }
    return .success
  }

  private func retryRefusal(_ remaining: UInt8) -> CredentialOutcome? {
    switch remaining {
    case 0:
      .blocked

    case 1...RetryCount.lowAttemptCeiling:
      .refusedLowAttempts(remaining: remaining)

    default:
      nil
    }
  }

  private func authenticationResult(
    from outcome: CredentialOutcome
  ) -> AuthenticationResult {
    switch outcome {
    case .blocked:
      .blocked

    case .refusedLowAttempts(let remaining):
      .refusedLowAttempts(remaining: remaining)

    case .transportFailure(let effect):
      .transportFailure(effect)

    case .rejected(let remaining):
      .rejected(remaining: remaining)

    case .success, .alreadyActivated, .invalidEntry:
      .invalidEntry
    }
  }

  private func credentialIsValid(
    _ digits: String,
    for role: CredentialRole
  ) -> Bool {
    switch role {
    case .pin1:
      digitsAreValid(
        digits,
        within: Pin1.minimumDigitCount...Pin1.maximumDigitCount)

    case .pin2:
      digitsAreValid(
        digits,
        within: Pin2.minimumDigitCount...Pin2.maximumDigitCount)

    case .puk:
      digitsAreValid(
        digits,
        within: Puk.minimumDigitCount...Puk.maximumDigitCount)
    }
  }

  private func digitsAreValid(
    _ digits: String,
    within allowedCount: ClosedRange<Int>
  ) -> Bool {
    let asciiDigits = UInt8(ascii: "0")...UInt8(ascii: "9")
    return allowedCount.contains(digits.count)
      && digits.utf8.allSatisfy { asciiDigits.contains($0) }
  }

  private func credential(for role: CredentialRole) -> CredentialState {
    switch role {
    case .pin1:
      current.card.pin1

    case .pin2:
      current.card.pin2

    case .puk:
      current.card.puk
    }
  }

  private func setCredential(
    _ credential: CredentialState,
    for role: CredentialRole
  ) {
    switch role {
    case .pin1:
      current.card.pin1 = credential

    case .pin2:
      current.card.pin2 = credential

    case .puk:
      current.card.puk = credential
    }
  }

  private func consumeFault(
    for operation: Operation,
    phase: FaultPhase
  ) -> FaultEffect? {
    guard
      let index = current.faults.firstIndex(where: { fault in
        (fault.operation == operation || fault.operation == .any)
          && fault.phase == phase
      })
    else {
      return nil
    }
    let effect = current.faults[index].effect
    if current.faults[index].remainingOccurrences > 1 {
      current.faults[index].remainingOccurrences -= 1
    } else {
      current.faults.remove(at: index)
    }
    switch effect {
    case .readerDisconnected:
      current.card.readerConnected = false
      current.card.cardPresent = false

    case .cardRemoved:
      current.card.cardPresent = false

    case .connectionLost, .timeout, .malformedResponse, .tokenNotPublished:
      break
    }
    return effect
  }
}
