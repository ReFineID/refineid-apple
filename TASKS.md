# Apple release task list

Last reviewed: 2026-09-05. Completed work is removed; this file holds only
outcomes still required for a beta, an App Store release, or the next
protocol milestone.

## Status

- First release: iPhone MVP on iOS 26. RELEASED: 26.8.21 (200), commit
  `cbd4b4a`, approved overnight and READY_FOR_SALE 2026-08-22 - the
  version auto-released on approval (Documentation/releases/26.8.21.md).
  Tagged `ios-v26.8.21-release.200`, GitHub release published. Automatic
  release on approval is the standing policy (runbook section 7).
- Version 26.9.5: Physical smart card reader web authentication from Mac via
  iPhone RAPP proxy verified live on `https://card.refineid.fi/` with native
  PIN 1 prompts on iOS, reader priority over wireless presence, and PIN 2
  excluded from macOS browser identities. In-band encrypted card departure
  signaling specified in `Documentation/card-departure-privacy-and-signaling-plan.md`.
  Experimental iOS 16 backport dropped; platform floor is firmly 26.0 for iOS/macOS.
- Ships: one-step NFC priming, Safari login, document signing and checking,
  PIN changes, USB-C reader signing, demo mode (virtual card starts activated).
- Gated out of TestFlight/Release: remote card (`REFINEID_REMOTE_CARD`) and
  activation (`FEATURE_CARD_ACTIVATION`; unactivated cards see a localized
  refusal). Shipping configs: floor 26, iPhone-only, `nfc` required
  capability, `Config/ReFineID-iOS-Store-Info.plist` (no Bonjour or
  local-network keys). Debug/Profile: floor 26, both families, gates on.
  Enforced by the archive inspector and `RappShippingConfigurationTests`.

## Release blockers

None. The non-UI suite (CardCoreTests and ReFineIDTests, 597 tests across 107 suites) is fully green on main.

The RAPP physical qualification matrix is not a blocker here; it gates
re-enabling `REFINEID_REMOTE_CARD` and the macOS release (Phase E below).

## Deterministic safety verification


- [ ] Make the retry floor provable: the NFC deadline path transmits PIN 1
  without an immediately preceding probe (doc and exception must agree); zero
  attempts transmits instead of refusing (`refuseBlocked` unreachable);
  enforcement is convention, not type; no test proves zero credential
  commands on a floor refusal. Never exercise a real card's final attempt.
- [ ] Instrument test transports on every credential path; prove exact
  card-command counts for success, rejection, ambiguity, retry refusal.
- [ ] Cover retry states unknown, malformed, 0–4, pristine, including
  wrong-at-three → two with no later transmission.
- [ ] Finish the Virtual ID Card XCUITest harness: state machine, editor,
  VoiceOver, localization, transports, injected failures through the same
  paths as real cards.
- [ ] Prove store archives contain no diagnostics, logging, credential APDUs,
  secrets, personal data, or debug-only UI.
- [ ] Run keyboard, VoiceOver, Dynamic Type, contrast, reduced-motion,
  focus-order, error-announcement, and Accessibility Inspector coverage for
  every shipping state.

## Exact-build hardware evidence

- [ ] Verify activation

## App Store release

- [ ] Give App Review accurate card/reader instructions, Virtual ID Card
  steps, hardware limitations, extension behavior.
- [ ] Localized `What's New` drafts from the exact diff, human-approved.

## Xcode Cloud

- [ ] Connect with minimum access and a deterministic verification workflow
  on the committed shared scheme.
- [ ] Tag-driven internal, beta, and rc workflows; no automatic distribution
  per source change.
- [ ] Retain build, test, analysis, inspection, and rc evidence beyond Xcode
  Cloud's retention window.

## Automatic & Secure Same-AppleID Device Pairing

Read `Documentation/same-apple-id-automatic-pairing.md` for architecture and cryptographic specification.

- [x] Phase 1: Cloud synchronization layer (`RappCloudSyncCoordinator`) backed by `NSUbiquitousKeyValueStore` to securely distribute public keys, device metadata, and rendezvous seeds across user's devices without syncing private keys.
- [x] Phase 2: Noise IK / KK (`Noise_KK_25519_ChaChaPoly_SHA256`) pre-authenticated mutual handshake derivation (`RappSameAccountPairBuilder`, `RappDeviceIdentity`) for zero-interaction pairing between devices on the same Apple ID.
- [x] Phase 3: Hardware-first priority arbitration (`CardSourceArbitrator`) and automatic background service sync (`RappAutoPairingService`) when a Mac or iPad opens ReFineID and requests smart card operations from the card-holding iPhone.
- [x] Phase 4: Full test coverage and end-to-end integration test (`RappAutoPairingIntegrationTests`) verifying multi-device 1:N reconciliation across iPhone, iPad, and Mac.

## RAPP

- [ ] Prototype interoperable non-Apple requesters and authorizers after the
  Apple release baseline is frozen.

## RAPP handoff

Read `Documentation/rapp-implementation-handoff.md` before changing RAPP.

The protocol engine is implemented in 100% native Swift in
`CardCore/Sources/RappEngine`; its authority is the vendored spec, formal
state model, and conformance corpus, and its tests fail on disagreement.

Done: pairing, authenticated transport, explicit phone-holder authorization,
browser auth, document signing, acknowledgements, durable
selection/revocation, one-violation durable fail-stop. macOS ships separate
reader and RAPP CTK extensions (smart-card vs network entitlements, never
both). CardCore test suites (`CardCoreTests`, `RappEngineTests`) green.
Activation and PIN management are deliberately not RAPP operations.

Not proved: the physical two-device matrix (Phase E); a hardware-free RAPP UI
harness — it must run the real coordinators and may virtualize only
transport and card effects, never inject SwiftUI state; independent interop
and external security review. The 2026-08-17 iPad-requester run is evidence.

Next: blocker 1; then the hardware-free harness (start at `RappPairingUI`,
`RappAuthorizationInbox`, `RappPhoneProxyDispatcher`,
`PhonePersistentTokenRelay`; inject below the dispatcher/card boundary); then
bounded UI-test shards (pairing, approve/deny, PIN 2, fail-stop,
revocation/re-pair, VoiceOver, Dynamic Type, fi/sv/en). Push each coherent
increment; update the handoff when the pinned Rust revision or evidence
changes.

### RAPP plan

Phases in order; a later phase may start early only if it does not weaken or
bypass the production protocol path.

- A, reproducible baseline: change spec and formal model first, regenerate
  and re-vendor corpus/vectors, then the engine; push Rust before the Apple
  commit that pins it. Accept: clean checkout builds with Xcode alone; the
  release manager rejects mismatched provenance; both RAPP suites green.
- B, hardware-free seam: narrow seams for peer transport and card effects,
  production defaults unchanged; an in-memory duplex transport between two
  real coordinators carrying real frames (may drop, duplicate, reorder,
  corrupt, expire; never synthesizes success); Virtual ID Card as the card
  effects; injectable time/entropy at the test boundary only; tests reach no
  real reader, NFC, Keychain, or credential store without opt-in. Accept: one
  process runs pair→session→operation→authorize→execute→acknowledge with real
  peers; frame mutation produces production fail-stop; no test branch assigns
  UI state.
- C, Debug-only UI driver: launch controls for isolated vault, in-memory
  transport, fixtures, scenarios, rejected outside Debug; pairing driven
  through the visible controls (scanner replaceable, the URI must be a real
  offer); editor and sheets localized fi/sv/en and fully accessible; no
  secrets in accessibility text; shards below the device timeout. Accept:
  VoiceOver-only walkthrough works; the release manager proves the driver
  absent from store archives.
- D, behavior matrix: pairing (offer, review, approval, persistence,
  reconnect; denial, malformed/expired offer, transport loss per phase,
  removal, durable revocation, re-pair with new keys); operations (status,
  browser auth, signing with PIN 2 on the phone only, busy, cancel, expiry,
  card removal, completion ambiguity, safe reconnect); fail-stop (bad
  credentials, corruption, replay, sequence violation, identity mismatch —
  first authenticated violation durably revokes, no retry or silent re-pair;
  credential rejection clears local state; activation/PIN management always
  rejected). Accept: every formal transition tested both ways; exact
  card-command counts proven, retry-floor refusal proves zero; durable state
  asserted after restart.
- E, physical qualification: record hashes, versions, devices, card, reader,
  sanitized start state; QR pairing, status, Safari auth, signing, denial,
  card removal, relay loss, app/extension restart, one synthetic fail-stop,
  durable revocation, re-pairing; extensions never claim each other's
  capability; never spend a real credential retry. Accept: the exact archived
  candidate passes the whole recorded matrix without dev-only crutches.
- F, independent interop and review: a minimal independent peer from the
  published spec and corpus (no shared Rust); cross-run the vectors; external
  review of crypto, pairing ceremony, transcript binding, replay, privacy,
  DoS, local-network exposure, teardown; high-severity findings resolved
  before TestFlight, accepted risks recorded with owner and date. Accept:
  interop without Apple-private assumptions; docs match code and corpus.
- G, freeze and distribute: all gates through the release manager; notes from
  the exact diff, human-reviewed before upload; never rebuild between
  qualification and upload; record identifiers, provenance, tester groups,
  rollback decision. Accept: uploads hash-match the qualified exports;
  archives carry no debug harness.
