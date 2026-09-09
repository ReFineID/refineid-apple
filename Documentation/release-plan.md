# macOS App Store release plan

Last reviewed: 2026-09-05

This document defines the product, security, validation, and distribution gates
for the Swift macOS ReFineID release. [TASKS.md](../TASKS.md) is the
checkable execution list. If the two documents disagree, this plan controls until
the disagreement is resolved in a reviewed change.

The executable human and automation procedure is the
[macOS App Store release runbook](release-runbook.md). The plan defines what
must be true; the runbook defines how an approved release operator proves and
executes it.

This document's iOS and NFC exclusions apply only to the macOS artifact. They
must not be applied to iPhone: built-in NFC is a required production transport
in its TestFlight and App Store builds. Its scope is controlled by
`Documentation/ios-product-plan.md` and
`Documentation/card-transports.md`.

## Release objective

Ship a small, trustworthy macOS App Store product named **ReFineID**.

The application contains the CryptoTokenKit smart-card extension that macOS
loads for a supported card, with direct contact reader signing enabled in the
initial store release. A separate persistent-token extension for a RAPP-paired
iPhone authorizer is fully developed in Debug and Profile configurations and
compile-gated out of shipping store builds (`hasRapp: false`) pending physical
qualification.

User story is:

1. Install ReFineID from the Mac App Store.
2. Insert supported Finnish identity card into a reader.
3. Open ReFineID and see that the extension, reader, and card are available.
4. See PIN1, PIN2, and PUK retry state.
5. Use the card's authentication certificate in a system CryptoTokenKit client.
6. Enter PIN1 through the system authentication flow when required.

## Product

### Included

- A sandboxed, native Swift macOS application.
- A native Swift CryptoTokenKit smart-card token extension embedded in the app.
- In Debug/Profile (and subsequent RAPP release): a persistent-token extension
  that delegates explicitly authorized card operations to a cryptographically
  paired iPhone through RAPP without transferring CAN, PIN 1, or PIN 2 to the Mac.
- Supported-card, reader, extension, and application version status.
- Display of PIN1, PIN2, and PUK attempts remaining.
- Publication of the card's PIN1 authentication identity to macOS for browser/TLS use.
- PIN1-gated authentication signatures for the explicitly supported card and
  key profiles.
- A memory-only, card-bound PIN1 convenience cache.
- Card management in the app: card activation, PIN1/PIN2 changes, and PUK
  unblock, each behind the same side-effect-free retry floor as
  authentication.
- PIN2 qualified-signature support for explicit in-app document signing,
  gated behind a per-signature PIN2 prompt with no cache. (PIN2 identities
  are excluded from WebKit/browser client certificate evaluation).
- Clear no-card, unsupported-card, low-retry, locked-card, and uncertain-state
  guidance in Finnish, Swedish, and English.

### Excluded

- The `refineid` command line tool or any command line installer.
- Rust libraries, Rust runtime code, helper executables, daemons, or privileged
  helpers in the App Store artifact.
- Portrait and stored handwritten-signature display.
- Safari extensions, browser shells, Internet relays, macOS NFC, telemetry,
  analytics, accounts, and cloud services.

Card management and PIN2 signing entered scope on 2026-08-04 (see
`Documentation/decisions.md`); iPadOS and iOS follow the macOS
implementation.

### Delivery sequence

| Milestone | Outcome |
| --- | --- |
| M4 - Release evidence | Security, clean-archive, accessibility, clean-Mac, and real-card hardware matrices pass for an exact cloud build. |
| M5 - TestFlight | Explicit development, beta, and release-candidate tags distribute through the configured tester groups. |
| M6 - App Store | The exact tested candidate passes App Review and is released manually with public source and support ready. |

## Architecture

The shipping App Store archive embeds the direct smart-card token extension:

```text
ReFineID.app
|-- Contents/MacOS/ReFineID
|-- Contents/PlugIns/ReFineIDTokenExtension.appex
`-- Contents/Resources/...
```

Development and Profile builds embed both extensions, enabling RAPP testing:

```text
ReFineID.app (Debug/Profile)
|-- Contents/MacOS/ReFineID
|-- Contents/PlugIns/ReFineIDTokenExtension.appex
|-- Contents/PlugIns/ReFineIDRappTokenExtension.appex
`-- Contents/Resources/...
```

The repository keeps a stable Xcode project or workspace in version control.
It must not depend on a project generator during Xcode Cloud onboarding or
release builds.

The Swift implementation follows the protocol specification and formal model.

### Retry floor

On a reader field with enough time, immediately before a CTK PIN-bearing
command, obtain the retry state of the credential that command will spend
without sending a credential. Perform the check and credential command in one
exclusive card transaction. Authentication reads PIN1 only. It never reads PIN2
or PUK; those counters belong to qualified-signature and recovery operations
and remain available to the explicit status display.

The system-driven iPhone NFC field is the measured exception. Its deadline does
not leave room for a diagnostic APDU before VERIFY and the signature, so it uses
only the PIN1 the holder explicitly stored. A confirmed rejection immediately
revokes that automatic identity. It still never probes PIN2 or PUK.

- Three or more attempts remaining: the CTK operation may proceed.
- One or two attempts remaining: refuse before prompting for or sending the PIN.
- Zero attempts remaining: report the credential as blocked.
- Missing, malformed, stale, or unreadable retry state: reject attempt to talk to card.
- CTK has no expert override.

If a wrong PIN1 sent at three attempts leaves two attempts, clear positive PIN1
state and refuse every later authentication operation. CTK must never consume
the last attempt and never sends PIN1 when only one or two attempts remain.
Read-only status and certificate inspection remain available when safe.

### Accepted PIN1 memory

A PIN1 may enter memory only after the card has accepted it. The value is
bound to the complete card serial, stored in zeroizing memory on the live
token, and dies when that token dies: card removal or reader
disconnection. There is no timer. Every reader signature still obtains
fresh PIN1 retry state and sends VERIFY PIN1; the memory removes repeated
user entry, not card verification. PIN2 and PUK never enter this memory.

The first confirmed PIN1 rejection clears that card's accepted PIN memory. For
an automatically configured iOS identity it also removes stored PIN1, that
physical card's prime, and its CryptoTokenKit registration. Transport, PACE,
signature, and TLS failures do not revoke identity state.

## User experience

The clean-machine trust story is part of this experience. The Store app neither
uses administrator authorization nor silently modifies system trust settings.

The application uses native SwiftUI and AppKit only where SwiftUI does not expose
the required macOS behavior. It supports keyboard navigation, VoiceOver,
increased contrast, reduced motion, text scaling where applicable, and clear
focus and error states. The icon follows the current Apple Human Interface
Guidelines and is built from owned source artwork.

### Calendar versioning

- **Version (`CFBundleShortVersionString`):** `YY.M.D` of the release day in
  UTC, without zero padding, for example `26.7.23`.
  Apple accepts at most three period-separated integers, so the year owns the
  first component and at most one App Store release ships per day.
- **Build number (`CFBundleVersion`):** the ten-minute bucket of UTC
  at which the build was cut: hour times ten plus the tens digit of the
  minute. `130` means 13:00-13:09; `93` means 09:30-09:39. At most one build
  per bucket. UTC, not local time: local time repeats an hour at the autumn
  daylight-saving fall-back and depends on the build machine's zone, either of
  which could make a build number collide or decrease. Buckets increase
  strictly within a day. Build numbers restart
  each day, which is valid because App Store Connect requires build-number
  uniqueness only within one version string and the version changes daily.
- TestFlight and App Store Connect display the pair as `26.7.23 (130)`.

Xcode Cloud owns App Store signing. The repository contains no certificate
private keys, provisioning profiles, API keys, or Apple account credentials.
Secret environment values, if ever required, are redacted in Xcode Cloud.

## Apple references

- [CryptoTokenKit](https://developer.apple.com/documentation/cryptotokenkit)
- [`TKSmartCardTokenDriver`](https://developer.apple.com/documentation/cryptotokenkit/tksmartcardtokendriver)
- [Creating a smart-card app extension](https://developer.apple.com/documentation/cryptotokenkit/authenticating-users-with-a-cryptographic-token)
- [Smart-card entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.smartcard)
- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Configuring macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Setting up Xcode Cloud](https://developer.apple.com/documentation/xcode/setting-up-your-project-to-use-xcode-cloud)
- [Xcode Cloud workflow reference](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference)
- [Writing Xcode Cloud custom build scripts](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Preparing hardware-dependent apps for App Review](https://developer.apple.com/app-store/review/)
- [Managing App Store privacy information](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple app-icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Performing accessibility audits](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)
- [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels/)
